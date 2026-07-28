#!/usr/bin/env bash
# install.sh — Automated NixOS installer (ext4)
#
# Partitions, formats, mounts, clones the flake repo, generates
# hardware-configuration.nix, and runs nixos-install.
#
# Usage:
#   sudo bash install.sh                                    # interactive mode
#   sudo bash install.sh <disk> --host HOST --efi-size SIZE --swap-size SIZE
#                         [--home-disk DISK | --home-size SIZE]
#   sudo bash install.sh --help
#
# Interactive mode:
#   Run with no arguments to be prompted for each value.
#   Any flags provided on the command line are used as-is;
#   only missing values are prompted interactively.
#
# Size format:
#   Use a number followed by a unit: M (mebibytes) or G (gibibytes).
#   Examples: 512M, 1G, 2G, 48G, 200G
#   Both short (2G) and long (2GiB) forms are accepted.
#
# Examples:
#   # Interactive — prompts for all values
#   sudo bash install.sh
#
#   # JIN — 2-drive setup (OS + dedicated /home drive)
#   sudo bash install.sh /dev/nvme0n1 \
#     --host JIN --efi-size 2G --swap-size 48G \
#     --home-disk /dev/nvme1n1
#
#   # JIN — single disk, no separate /home
#   sudo bash install.sh /dev/nvme0n1 \
#     --host JIN --efi-size 2G --swap-size 48G
#
#   # Single disk with /home partition
#   sudo bash install.sh /dev/sda \
#     --host MYHOST --efi-size 512M --swap-size 16G \
#     --home-size 200G
#
#   # Reinstall OS but keep existing /home data on second drive
#   sudo bash install.sh /dev/nvme0n1 \
#     --host JIN --efi-size 2G --swap-size 48G \
#     --home-disk /dev/nvme1n1 --keep-home
#
# WARNING: This script will DESTROY all data on the target disk(s).

set -euo pipefail

SECONDS=0
trap 'umount -R /mnt 2>/dev/null || true; swapoff -a 2>/dev/null || true; elapsed=$SECONDS; printf "\n%b Total time: %dm %ds\n" "${BOLD:-}[install]${NC:-}" $((elapsed/60)) $((elapsed%60))' EXIT

# ──────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────
FLAKE_REPO="https://github.com/elvismercado/infra-nix-config.git"
REPO_NAME="$(basename "${FLAKE_REPO}" .git)"
FLAKE_HOST=""
USERNAME=""
REPO_DIR=""
DISK=""
EFI_SIZE=""
SWAP_SIZE=""
HOME_SIZE=""              # empty = no separate /home partition (single-disk mode)
HOME_DISK=""              # empty = no dedicated /home disk (set via --home-disk)
KEEP_HOME=""              # non-empty = mount existing /home disk without formatting
TEMP_REPO=""              # set by clone_repo() via mktemp -d

# Labels (used for mounting by label)
LABEL_BOOT="BOOT"
LABEL_ROOT="nixos"
LABEL_HOME="home"
LABEL_SWAP="swap"

# Minimum root partition size (MiB). Root holds /nix/store which grows with
# each NixOS generation. 20 GiB provides comfortable headroom.
MIN_ROOT_MIB=20480

# Minimum EFI partition size (MiB). FAT32 needs ~33 MiB overhead;
# UEFI spec recommends at least 100 MiB.
MIN_EFI_MIB=100

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[install]${NC} $*"; }
warn()  { echo -e "${YELLOW}[install]${NC} $*"; }
error() { echo -e "${RED}[install]${NC} $*" >&2; }
fatal() { error "$@"; exit 1; }

# Normalize a size value to parted-compatible format.
# Accepts: 512M, 2G, 512m, 2g, 512MiB, 2GiB
# Returns: 512MiB, 2GiB (via stdout)
normalize_size() {
  local input="$1"
  local label="${2:-size}"   # label for error messages (e.g. "efi-size")

  # Strip whitespace
  input="${input// /}"

  # Match number + unit
  if [[ "$input" =~ ^([0-9]+)[Gg]([Ii][Bb])?$ ]]; then
    echo "${BASH_REMATCH[1]}GiB"
  elif [[ "$input" =~ ^([0-9]+)[Mm]([Ii][Bb])?$ ]]; then
    echo "${BASH_REMATCH[1]}MiB"
  else
    fatal "Invalid ${label}: '${input}'. Use a number with M or G (e.g. 512M, 2G, 48G)."
  fi
}

# Convert a normalized size (e.g. 2GiB, 512MiB) to mebibytes for arithmetic.
size_mib() {
  local input="$1"
  if [[ "$input" =~ ^([0-9]+)GiB$ ]]; then
    echo $(( ${BASH_REMATCH[1]} * 1024 ))
  elif [[ "$input" =~ ^([0-9]+)MiB$ ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    fatal "size_mib: unexpected format '${input}'"
  fi
}

# Return the usable size of a block device in whole MiB (floored).
# Flooring guarantees all MiB-based partition boundaries are sector-aligned.
disk_mib() {
  local device="$1"
  local bytes
  bytes=$(blockdev --getsize64 "$device")
  echo $(( bytes / 1048576 ))
}

# Validate that the requested partitions fit on the target disk(s).
# Must be called after all sizes are finalized, before confirm_destroy().
validate_disk_capacity() {
  local efi_mib swap_mib total_mib required_mib root_mib

  efi_mib=$(size_mib "$EFI_SIZE")
  swap_mib=$(size_mib "$SWAP_SIZE")
  total_mib=$(disk_mib "$DISK")

  if (( efi_mib < MIN_EFI_MIB )); then
    fatal "EFI partition (${EFI_SIZE}) is too small. Minimum is ${MIN_EFI_MIB} MiB for FAT32."
  fi

  if [[ -n "$HOME_SIZE" ]] && [[ -z "$HOME_DISK" ]]; then
    # 4-partition layout on a single disk: EFI + root + home + swap
    local home_mib
    home_mib=$(size_mib "$HOME_SIZE")
    required_mib=$(( efi_mib + MIN_ROOT_MIB + home_mib + swap_mib ))
    root_mib=$(( total_mib - efi_mib - home_mib - swap_mib ))
  else
    # 3-partition layout: EFI + root + swap (home on separate disk or not used)
    required_mib=$(( efi_mib + MIN_ROOT_MIB + swap_mib ))
    root_mib=$(( total_mib - efi_mib - swap_mib ))
  fi

  if (( required_mib > total_mib )); then
    echo ""
    fatal "Partitions do not fit on ${DISK} ($(( total_mib / 1024 )) GiB).\n" \
          "  Requested: EFI ${EFI_SIZE} + swap ${SWAP_SIZE}${HOME_SIZE:+ + home ${HOME_SIZE}} + root ≥ $(( MIN_ROOT_MIB / 1024 )) GiB = $(( required_mib / 1024 )) GiB minimum\n" \
          "  Root would get $(( root_mib / 1024 )) GiB — need at least $(( MIN_ROOT_MIB / 1024 )) GiB.\n" \
          "  Reduce partition sizes or use a larger disk."
  fi

  # Validate separate home disk capacity
  if [[ -n "$HOME_DISK" ]] && [[ -n "$HOME_SIZE" ]]; then
    local home_mib home_total_mib
    home_mib=$(size_mib "$HOME_SIZE")
    home_total_mib=$(disk_mib "$HOME_DISK")
    if (( home_mib > home_total_mib )); then
      fatal "Home partition (${HOME_SIZE}) does not fit on ${HOME_DISK} ($(( home_total_mib / 1024 )) GiB)."
    fi
  fi

  info "Disk capacity check passed — root partition will get $(( root_mib / 1024 )) GiB."
}

# ──────────────────────────────────────────────────────────────
# Interactive prompts
# ──────────────────────────────────────────────────────────────

# Prompt for a size value (e.g. EFI, swap). Validates via normalize_size.
# Usage: prompt_size "EFI partition size" "e.g. 512M, 2G" VARIABLE_NAME
prompt_size() {
  local label="$1"
  local example="$2"
  local varname="$3"
  local input normalized

  while true; do
    read -rp "  ${label} (${example}): " input
    if [[ -z "$input" ]]; then
      warn "A value is required."
      continue
    fi
    # Try to normalize — on failure, re-prompt instead of exiting
    if normalized=$(normalize_size "$input" "$label" 2>&1); then
      printf -v "$varname" '%s' "$normalized"
      return
    else
      warn "Invalid size '${input}'. Use a number with M or G (e.g. 512M, 2G, 48G)."
    fi
  done
}

# Prompt for a block device via numbered selection menu.
# Usage: prompt_disk "OS disk" VARIABLE_NAME
prompt_disk() {
  local label="$1"
  local varname="$2"
  local disks=() disk_lines=() line dev

  # Enumerate physical disks — exclude loop (7) and CD-ROM (11) devices
  while IFS= read -r line; do
    dev=$(echo "$line" | awk '{print $1}')
    # Skip the already-selected OS disk when choosing a home disk
    if [[ -n "$DISK" && "$dev" == "$DISK" ]]; then
      continue
    fi
    disks+=("$dev")
    disk_lines+=("$line")
  done < <(lsblk -dnp -o NAME,SIZE,MODEL,TRAN --exclude 7,11 2>/dev/null)

  if [[ ${#disks[@]} -eq 0 ]]; then
    fatal "No available disks found."
  fi

  echo ""
  info "Select ${label}:"
  echo ""
  local i
  for i in "${!disk_lines[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${disk_lines[$i]}"
  done
  echo ""

  local choice
  while true; do
    read -rp "  ${label} [1-${#disks[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#disks[@]} )); then
      printf -v "$varname" '%s' "${disks[$((choice - 1))]}"
      info "Selected: ${BOLD}${disks[$((choice - 1))]}${NC}"
      return
    fi
    warn "Enter a number between 1 and ${#disks[@]}."
  done
}

# Prompt the user to select a host from the cloned repo.
# Populates FLAKE_HOST.
prompt_host() {
  local hosts=() dir settings

  # Scan for hosts that have user-settings.nix
  for dir in "${TEMP_REPO}"/hosts/*/; do
    settings="${dir}user-settings.nix"
    if [[ -f "$settings" ]]; then
      # Check if it's a NixOS host (system contains linux)
      if grep -q 'linux' "$settings" 2>/dev/null; then
        hosts+=("$(basename "$dir")")
      fi
    fi
  done

  if [[ ${#hosts[@]} -eq 0 ]]; then
    fatal "No NixOS hosts found in the repo (no hosts/*/user-settings.nix with linux system)."
  fi

  echo ""
  info "Available NixOS hosts:"
  echo ""
  local i
  for i in "${!hosts[@]}"; do
    echo "  $((i + 1))) ${hosts[$i]}"
  done
  echo ""

  local choice
  while true; do
    read -rp "  Select host [1-${#hosts[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#hosts[@]} )); then
      FLAKE_HOST="${hosts[$((choice - 1))]}"
      info "Selected: ${BOLD}${FLAKE_HOST}${NC}"
      return
    fi
    warn "Enter a number between 1 and ${#hosts[@]}."
  done
}

# Prompt for home setup — dedicated disk, partition on OS disk, or none.
# Populates HOME_DISK or HOME_SIZE (or neither).
prompt_home_setup() {
  echo ""
  info "Home partition setup:"
  echo ""
  echo "  1) No separate /home partition (root holds everything)"
  echo "  2) Dedicated home disk (second drive)"
  echo "  3) /home partition on the OS disk"
  echo ""

  local choice
  while true; do
    read -rp "  Choice [1-3]: " choice
    case "$choice" in
      1)
        return
        ;;
      2)
        prompt_disk "Home disk" HOME_DISK
        if [[ "$HOME_DISK" == "$DISK" ]]; then
          warn "Home disk must be different from the OS disk (${DISK}). Try again."
          HOME_DISK=""
          continue
        fi
        echo ""
        local fmt_choice
        read -rp "  Format this disk? WARNING: destroys all data [y/N]: " fmt_choice
        if [[ "$fmt_choice" =~ ^[Yy]$ ]]; then
          KEEP_HOME=""
          info "Home disk will be formatted."
        else
          KEEP_HOME=1
          info "Home disk will be mounted as-is (existing data preserved)."
        fi
        return
        ;;
      3)
        prompt_size "Home partition size" "e.g. 100G, 200G" HOME_SIZE
        return
        ;;
      *)
        warn "Enter 1, 2, or 3."
        ;;
    esac
  done
}

# Fill in any missing configuration values interactively.
interactive_config() {
  # Host
  if [[ -z "$FLAKE_HOST" ]]; then
    prompt_host
  fi

  # Resolve username now that host is known
  resolve_username

  # OS disk
  if [[ -z "$DISK" ]]; then
    prompt_disk "OS disk" DISK
  fi

  # EFI size
  if [[ -z "$EFI_SIZE" ]]; then
    echo ""
    prompt_size "EFI partition size" "e.g. 512M, 2G" EFI_SIZE
  fi

  # Swap size
  if [[ -z "$SWAP_SIZE" ]]; then
    prompt_size "Swap partition size" "e.g. 16G, 48G" SWAP_SIZE
  fi

  # Home setup (only if neither --home-disk nor --home-size was provided)
  if [[ -z "$HOME_DISK" ]] && [[ -z "$HOME_SIZE" ]]; then
    prompt_home_setup
  fi
}

# ──────────────────────────────────────────────────────────────
# Preconditions
# ──────────────────────────────────────────────────────────────
check_preconditions() {
  [[ $EUID -eq 0 ]] || fatal "This script must be run as root (sudo)."

  if ! grep -qi nixos /etc/os-release 2>/dev/null; then
    fatal "This script must be run from the NixOS installer environment."
  fi

  command -v parted  >/dev/null 2>&1 || fatal "'parted' not found."
  command -v mkfs.ext4 >/dev/null 2>&1 || fatal "'mkfs.ext4' not found."
  command -v mkfs.fat  >/dev/null 2>&1 || fatal "'mkfs.fat' not found."
  command -v mkswap  >/dev/null 2>&1 || fatal "'mkswap' not found."
  command -v wipefs  >/dev/null 2>&1 || fatal "'wipefs' not found."
}

# ──────────────────────────────────────────────────────────────
# Argument parsing
# ──────────────────────────────────────────────────────────────
show_usage() {
  echo "Usage: sudo bash install.sh                                    # interactive"
  echo "       sudo bash install.sh <disk> --host HOST --efi-size SIZE --swap-size SIZE"
  echo "                             [--home-disk DISK | --home-size SIZE]"
  echo "       sudo bash install.sh --help"
  echo ""
  echo "If no arguments are given, the script prompts for each value interactively."
  echo "Any flags provided are used as-is; only missing values are prompted."
  echo ""
  echo "Flags:"
  echo "  <disk>            OS disk (e.g. /dev/nvme0n1, /dev/sda)"
  echo "  --host HOST       Flake host name (e.g. JIN)"
  echo "  --efi-size SIZE   EFI partition size (e.g. 512M, 2G)"
  echo "  --swap-size SIZE  Swap partition size (e.g. 16G, 48G)"
  echo "  --home-disk DISK  Dedicated disk for /home (e.g. /dev/nvme1n1)"
  echo "  --home-size SIZE  /home partition size on the OS disk (e.g. 200G)"
  echo "  --keep-home       Mount existing /home disk without formatting (use with --home-disk)"
  echo "  --help            Show this help message"
  echo ""
  echo "Size format:"
  echo "  Use a number followed by a unit: M (mebibytes) or G (gibibytes)."
  echo "  Both short (2G) and long (2GiB) forms are accepted."
  echo "  Examples: 512M  1G  2G  16G  48G  200G"
  echo ""
  echo "Examples:"
  echo "  # Interactive — prompts for all values"
  echo "  sudo bash install.sh"
  echo ""
  echo "  # 2-drive setup (OS + dedicated /home drive)"
  echo "  sudo bash install.sh /dev/nvme0n1 \\"
  echo "    --host JIN --efi-size 2G --swap-size 48G \\"
  echo "    --home-disk /dev/nvme1n1"
  echo ""
  echo "  # Single disk, no separate /home"
  echo "  sudo bash install.sh /dev/nvme0n1 \\"
  echo "    --host JIN --efi-size 2G --swap-size 48G"
  echo ""
  echo "  # Single disk with /home partition"
  echo "  sudo bash install.sh /dev/sda \\"
  echo "    --host MYHOST --efi-size 512M --swap-size 16G \\"
  echo "    --home-size 200G"
  echo ""
  echo "  # Reinstall OS but keep existing /home data on second drive"
  echo "  sudo bash install.sh /dev/nvme0n1 \\"
  echo "    --host JIN --efi-size 2G --swap-size 48G \\"
  echo "    --home-disk /dev/nvme1n1 --keep-home"
}

parse_args() {
  # No arguments → interactive mode (all values prompted later)
  [[ $# -gt 0 ]] || return 0

  # Check for --help anywhere in the arguments
  for arg in "$@"; do
    if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
      show_usage
      exit 0
    fi
  done

  # First positional argument is the OS disk (if it doesn't start with --)
  if [[ "$1" != --* ]]; then
    DISK="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        FLAKE_HOST="$2"
        shift 2
        ;;
      --efi-size)
        EFI_SIZE="$(normalize_size "$2" "efi-size")"
        shift 2
        ;;
      --swap-size)
        SWAP_SIZE="$(normalize_size "$2" "swap-size")"
        shift 2
        ;;
      --home-disk)
        HOME_DISK="$2"
        shift 2
        ;;
      --home-size)
        HOME_SIZE="$(normalize_size "$2" "home-size")"
        shift 2
        ;;
      --keep-home)
        KEEP_HOME=1
        shift
        ;;
      *)
        fatal "Unknown option: $1 (use --help for usage)"
        ;;
    esac
  done

  # Validate disks that were provided via flags
  if [[ -n "$DISK" ]]; then
    [[ -b "$DISK" ]] || fatal "Disk '$DISK' does not exist or is not a block device."
  fi

  if [[ -n "$HOME_DISK" ]]; then
    [[ -b "$HOME_DISK" ]] || fatal "Home disk '$HOME_DISK' does not exist or is not a block device."
    if [[ -n "$DISK" ]]; then
      [[ "$HOME_DISK" != "$DISK" ]] || fatal "Home disk must be different from the OS disk."
    fi
  fi

  if [[ -n "$HOME_DISK" ]] && [[ -n "$HOME_SIZE" ]]; then
    fatal "Cannot use both --home-disk and --home-size. Pick one."
  fi

  if [[ -n "$KEEP_HOME" ]] && [[ -z "$HOME_DISK" ]]; then
    fatal "--keep-home requires --home-disk."
  fi

  if [[ -n "$KEEP_HOME" ]] && [[ -n "$HOME_SIZE" ]]; then
    fatal "Cannot use both --keep-home and --home-size."
  fi
}

# Return the partition device path (handles NVMe vs SATA naming)
# e.g. partition_device /dev/nvme0n1 1 → /dev/nvme0n1p1
#      partition_device /dev/sda 1     → /dev/sda1
partition_device() {
  local disk="$1"
  local num="$2"
  if [[ "$disk" == *nvme* ]] || [[ "$disk" == *mmcblk* ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

# ──────────────────────────────────────────────────────────────
# Confirmation
# ──────────────────────────────────────────────────────────────
confirm_destroy() {
  echo ""
  echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  if [[ -n "$HOME_DISK" ]] && [[ -z "$KEEP_HOME" ]]; then
    echo -e "${RED}${BOLD}║  WARNING: ALL DATA ON BOTH DISKS WILL BE DESTROYED         ║${NC}"
  else
    echo -e "${RED}${BOLD}║  WARNING: ALL DATA ON THE OS DISK WILL BE DESTROYED        ║${NC}"
  fi
  echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  info "Configuration:"
  echo -e "  Host:     ${BOLD}${FLAKE_HOST}${NC}"
  echo -e "  User:     ${BOLD}${USERNAME}${NC}"
  echo -e "  Repo:     ${BOLD}${REPO_DIR}${NC}"
  echo "  EFI:      ${EFI_SIZE}"
  echo "  Swap:     ${SWAP_SIZE}"
  echo ""
  info "OS disk:   ${BOLD}${DISK}${NC}"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$DISK" 2>/dev/null || true
  echo ""
  if [[ -n "$HOME_DISK" ]]; then
    if [[ -n "$KEEP_HOME" ]]; then
      info "Home disk: ${BOLD}${HOME_DISK}${NC} (keeping existing data)"
    else
      info "Home disk: ${BOLD}${HOME_DISK}${NC}"
    fi
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS "$HOME_DISK" 2>/dev/null || true
    echo ""
  fi
  info "Partition plan (OS disk):"
  echo "  1. EFI  (/boot)  — ${EFI_SIZE}, FAT32"
  echo "  2. Root (/)      — remainder of disk, ext4"
  if [[ -n "$HOME_SIZE" ]]; then
    echo "  3. Home (/home)  — ${HOME_SIZE}, ext4"
    echo "  4. Swap          — ${SWAP_SIZE}, linux-swap"
  else
    echo "  3. Swap          — ${SWAP_SIZE}, linux-swap"
  fi
  if [[ -n "$HOME_DISK" ]]; then
    echo ""
    info "Partition plan (Home disk):"
    if [[ -n "$KEEP_HOME" ]]; then
      echo "  1. Home (/home)  — mount existing partition (no format)"
    else
      echo "  1. Home (/home)  — entire disk, ext4"
    fi
  fi
  echo ""
  read -rp "Type 'yes' to continue: " answer
  [[ "$answer" == "yes" ]] || fatal "Aborted."
}

# ──────────────────────────────────────────────────────────────
# Unmount anything on the target disk
# ──────────────────────────────────────────────────────────────
unmount_disk() {
  info "Unmounting any existing partitions on ${DISK}..."
  umount -R /mnt 2>/dev/null || true
  swapoff "$(partition_device "$DISK" 3)" 2>/dev/null || true
  swapoff "$(partition_device "$DISK" 4)" 2>/dev/null || true
  for part in "${DISK}"*; do
    umount "$part" 2>/dev/null || true
    swapoff "$part" 2>/dev/null || true
  done
  if [[ -n "$HOME_DISK" ]]; then
    info "Unmounting any existing partitions on ${HOME_DISK}..."
    for part in "${HOME_DISK}"*; do
      umount "$part" 2>/dev/null || true
    done
  fi
}

# ──────────────────────────────────────────────────────────────
# Wipe disk signatures
# ──────────────────────────────────────────────────────────────
wipe_disk_signatures() {
  info "Wiping filesystem signatures on ${DISK}..."
  wipefs --all --force "$DISK"

  if [[ -n "$HOME_DISK" ]] && [[ -z "$KEEP_HOME" ]]; then
    info "Wiping filesystem signatures on ${HOME_DISK}..."
    wipefs --all --force "$HOME_DISK"
  fi
}

# ──────────────────────────────────────────────────────────────
# Partitioning
# ──────────────────────────────────────────────────────────────
partition_disk() {
  info "Creating GPT partition table on ${DISK}..."
  parted -s "$DISK" -- mklabel gpt

  # Compute usable disk size in MiB (floored) so all partition boundaries
  # land on MiB-aligned sectors, avoiding parted alignment warnings.
  local total_mib
  total_mib=$(disk_mib "$DISK")

  if [[ -n "$HOME_SIZE" ]]; then
    # 4-partition layout: EFI + Root + Home + Swap (single disk)
    local home_mib swap_mib swap_start_mib home_start_mib
    home_mib=$(size_mib "$HOME_SIZE")
    swap_mib=$(size_mib "$SWAP_SIZE")
    swap_start_mib=$((total_mib - swap_mib))
    home_start_mib=$((total_mib - swap_mib - home_mib))

    info "Creating EFI partition (${EFI_SIZE})..."
    parted -s "$DISK" -- mkpart ESP fat32 1MiB "$EFI_SIZE"
    parted -s "$DISK" -- set 1 esp on

    info "Creating root partition (remainder minus home and swap)..."
    parted -s "$DISK" -- mkpart root ext4 "$EFI_SIZE" "${home_start_mib}MiB"

    info "Creating home partition (${HOME_SIZE})..."
    parted -s "$DISK" -- mkpart home ext4 "${home_start_mib}MiB" "${swap_start_mib}MiB"

    info "Creating swap partition (${SWAP_SIZE})..."
    parted -s "$DISK" -- mkpart swap linux-swap "${swap_start_mib}MiB" 100%
  else
    # 3-partition layout: EFI + Root + Swap
    local swap_mib swap_start_mib
    swap_mib=$(size_mib "$SWAP_SIZE")
    swap_start_mib=$((total_mib - swap_mib))

    info "Creating EFI partition (${EFI_SIZE})..."
    parted -s "$DISK" -- mkpart ESP fat32 1MiB "$EFI_SIZE"
    parted -s "$DISK" -- set 1 esp on

    info "Creating root partition (remainder minus swap)..."
    parted -s "$DISK" -- mkpart root ext4 "$EFI_SIZE" "${swap_start_mib}MiB"

    info "Creating swap partition (${SWAP_SIZE})..."
    parted -s "$DISK" -- mkpart swap linux-swap "${swap_start_mib}MiB" 100%
  fi

  # Let the kernel re-read the partition table and wait for udev to process
  partprobe "$DISK" 2>/dev/null || true
  udevadm settle --timeout=30

  # Partition the dedicated home disk (entire disk = single ext4 partition)
  if [[ -n "$HOME_DISK" ]] && [[ -z "$KEEP_HOME" ]]; then
    info "Creating GPT partition table on home disk ${HOME_DISK}..."
    parted -s "$HOME_DISK" -- mklabel gpt

    info "Creating home partition (entire disk)..."
    parted -s "$HOME_DISK" -- mkpart home ext4 1MiB 100%

    partprobe "$HOME_DISK" 2>/dev/null || true
    udevadm settle --timeout=30
  elif [[ -n "$HOME_DISK" ]] && [[ -n "$KEEP_HOME" ]]; then
    info "Keeping existing partition table on home disk ${HOME_DISK}."
  fi
}

# ──────────────────────────────────────────────────────────────
# Formatting
# ──────────────────────────────────────────────────────────────
format_partitions() {
  local part_efi part_root part_swap part_home

  part_efi="$(partition_device "$DISK" 1)"
  part_root="$(partition_device "$DISK" 2)"

  if [[ -n "$HOME_SIZE" ]]; then
    part_home="$(partition_device "$DISK" 3)"
    part_swap="$(partition_device "$DISK" 4)"
  elif [[ -n "$HOME_DISK" ]]; then
    part_home="$(partition_device "$HOME_DISK" 1)"
    part_swap="$(partition_device "$DISK" 3)"
  else
    part_swap="$(partition_device "$DISK" 3)"
  fi

  info "Formatting EFI partition (${part_efi})..."
  mkfs.fat -F 32 -n "$LABEL_BOOT" "$part_efi"

  info "Formatting root partition (${part_root})..."
  mkfs.ext4 -L "$LABEL_ROOT" -F "$part_root"

  if [[ -n "$HOME_SIZE" ]]; then
    info "Formatting home partition (${part_home})..."
    mkfs.ext4 -L "$LABEL_HOME" -F "$part_home"
  elif [[ -n "$HOME_DISK" ]] && [[ -z "$KEEP_HOME" ]]; then
    info "Formatting home partition (${part_home})..."
    mkfs.ext4 -L "$LABEL_HOME" -F "$part_home"
  elif [[ -n "$HOME_DISK" ]] && [[ -n "$KEEP_HOME" ]]; then
    info "Skipping home partition format (--keep-home)."
  fi

  info "Creating swap (${part_swap})..."
  mkswap -L "$LABEL_SWAP" "$part_swap"

  # Wait for udev to (re)populate /dev/disk/by-label/* after mkfs/mkswap.
  # Without this, mount_partitions can race and fail with
  #   mount: /mnt: fsconfig() failed: /dev/disk/by-label/nixos: Can't lookup blockdev.
  udevadm settle --timeout=30
}

# ──────────────────────────────────────────────────────────────
# Mounting
# ──────────────────────────────────────────────────────────────
mount_partitions() {
  info "Mounting root partition on /mnt..."
  mount /dev/disk/by-label/"$LABEL_ROOT" /mnt

  info "Mounting EFI partition on /mnt/boot..."
  mkdir -p /mnt/boot
  mount -o umask=077 /dev/disk/by-label/"$LABEL_BOOT" /mnt/boot

  if [[ -n "$HOME_SIZE" ]] || ( [[ -n "$HOME_DISK" ]] && [[ -z "$KEEP_HOME" ]] ); then
    info "Mounting home partition on /mnt/home..."
    mkdir -p /mnt/home
    mount /dev/disk/by-label/"$LABEL_HOME" /mnt/home
  elif [[ -n "$HOME_DISK" ]] && [[ -n "$KEEP_HOME" ]]; then
    info "Mounting existing home partition on /mnt/home..."
    mkdir -p /mnt/home
    local home_part
    home_part="$(partition_device "$HOME_DISK" 1)"
    mount "$home_part" /mnt/home
  fi

  info "Enabling swap..."
  swapon /dev/disk/by-label/"$LABEL_SWAP"
}

# ──────────────────────────────────────────────────────────────
# Validate host exists in the cloned repo
# ──────────────────────────────────────────────────────────────
# Called early (before interactive_config) so CLI users get a fast error
# if --host points to a non-existent host. Skipped when FLAKE_HOST is
# empty — interactive_config will prompt for it via prompt_host().
validate_host() {
  [[ -n "$FLAKE_HOST" ]] || return 0

  local settings_file="${TEMP_REPO}/hosts/${FLAKE_HOST}/user-settings.nix"
  if [[ ! -f "$settings_file" ]]; then
    fatal "Host '${FLAKE_HOST}' not found — no file at hosts/${FLAKE_HOST}/user-settings.nix"
  fi
}

# ──────────────────────────────────────────────────────────────
# Clone flake repository
# ──────────────────────────────────────────────────────────────
clone_repo() {
  info "Cloning flake repository to temporary location..."

  TEMP_REPO=$(mktemp -d -t "${REPO_NAME}.XXXXXX") \
    || fatal "Failed to create temporary directory for clone."

  nix-shell -p git --run "git clone '${FLAKE_REPO}' '${TEMP_REPO}'" \
    || fatal "Failed to clone ${FLAKE_REPO}. Check your network connection and repository URL."
}

# ──────────────────────────────────────────────────────────────
# Resolve username and UID from the flake host's user-settings.nix
# ──────────────────────────────────────────────────────────────
resolve_username() {
  local settings_file="${TEMP_REPO}/hosts/${FLAKE_HOST}/user-settings.nix"

  # validate_host() already confirmed this file exists
  USERNAME=$(sed -n 's/.*username[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$settings_file" | head -1) \
    || fatal "Could not extract username from ${settings_file}"

  [[ -n "$USERNAME" ]] || fatal "Username is empty in ${settings_file}"

  # Validate USERNAME against POSIX spec: ^[a-z_][a-z0-9_-]{0,31}$
  # Defense-in-depth: USERNAME is interpolated into shell paths and chown commands.
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || fatal "Invalid username '${USERNAME}' in ${settings_file}. Must match ^[a-z_][a-z0-9_-]{0,31}$ (POSIX, max 32 chars)."

  # Read uid from user-settings.nix; default to 1000 (first normal user) if absent
  USER_UID=$(sed -n 's/.*uid[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "$settings_file" | head -1)
  USER_UID="${USER_UID:-1000}"

  # Validate USER_UID is in the normal user range (1000-65533).
  # Excludes 0 (root), system UIDs (<1000), and nobody (65534).
  if (( USER_UID < 1000 || USER_UID > 65533 )); then
    fatal "Invalid UID '${USER_UID}' in ${settings_file}. Must be in range 1000-65533 (normal user)."
  fi

  # Read repoPath from user-settings.nix; default to "git/${REPO_NAME}" if absent.
  # Must be a relative path (no leading '/') with no '..' segments — matches the
  # assertion in modules/systems/nixos/postinstall.nix.
  REPO_PATH=$(sed -n 's/.*repoPath[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$settings_file" | head -1)
  REPO_PATH="${REPO_PATH:-git/${REPO_NAME}}"

  if [[ "$REPO_PATH" == /* ]]; then
    fatal "Invalid repoPath '${REPO_PATH}' in ${settings_file}. Must be relative to \$HOME (no leading '/')."
  fi
  case "/${REPO_PATH}/" in
    */../*) fatal "Invalid repoPath '${REPO_PATH}' in ${settings_file}. Must not contain '..' segments." ;;
  esac

  REPO_DIR="/mnt/home/${USERNAME}/${REPO_PATH}"

  info "Resolved user: ${BOLD}${USERNAME}${NC} (UID ${USER_UID}) (from hosts/${FLAKE_HOST}/user-settings.nix)"
}

# ──────────────────────────────────────────────────────────────
# Deploy repository to final location under /mnt
# ──────────────────────────────────────────────────────────────
deploy_repo() {
  info "Deploying flake repository to ${REPO_DIR}..."
  mkdir -p "$(dirname "$REPO_DIR")"

  if [[ -d "$REPO_DIR" ]]; then
    warn "Repository already exists at ${REPO_DIR}, replacing..."
    rm -rf "$REPO_DIR"
  fi

  cp -a "$TEMP_REPO" "$REPO_DIR"

  # Set ownership to the target user (UID from user-settings.nix, GID 100 = NixOS 'users' group)
  # When keeping an existing /home, only chown the git directory to avoid a slow
  # recursive chown across all existing user data.
  if [[ -n "$KEEP_HOME" ]]; then
    chown -R "${USER_UID}:100" "/mnt/home/${USERNAME}/git"
  else
    chown -R "${USER_UID}:100" "/mnt/home/${USERNAME}"
  fi

  # Clean up temporary clone
  rm -rf "$TEMP_REPO"
}

# ──────────────────────────────────────────────────────────────
# Generate hardware configuration
# ──────────────────────────────────────────────────────────────
generate_hardware_config() {
  local hw_config="${REPO_DIR}/hosts/${FLAKE_HOST}/configuration/hardware-configuration.nix"

  info "Generating hardware configuration..."
  nixos-generate-config --show-hardware-config --root /mnt > "$hw_config" \
    || fatal "nixos-generate-config failed. Check that /mnt is properly mounted."

  # Validate the generated file is non-empty and contains fileSystems
  # (the critical attribute defining root/boot mounts).
  [[ -s "$hw_config" ]] \
    || fatal "Generated hardware-configuration.nix is empty: ${hw_config}"
  grep -q 'fileSystems' "$hw_config" \
    || fatal "Generated hardware-configuration.nix is missing fileSystems definitions: ${hw_config}"

  info "Hardware config written to: ${hw_config}"
  echo ""
  warn "Review the generated hardware configuration:"
  echo "────────────────────────────────────────────"
  cat "$hw_config"
  echo "────────────────────────────────────────────"
  echo ""

  # Commit the new file in the deployed repo. `nixos-install --flake .#<HOST>`
  # evaluates as `git+file:///<repo>?ref=...&rev=<HEAD>`, which only sees
  # files at HEAD — untracked `hardware-configuration.nix` would be invisible
  # at eval time and the build aborts with `path '...hardware-configuration.nix'
  # does not exist`. Plain `git add` (no commit) is unreliable here because the
  # explicit `rev=` pin in the URL bypasses the working tree/index entirely.
  # No push: install.sh has no SSH key for the user; postinstall.sh handles
  # publishing once the user has a working auth setup.
  info "Committing hardware-configuration.nix to the deployed repo (local-only)..."
  ( cd "${REPO_DIR}" && \
    git -c user.name=installer -c user.email=installer@localhost add -- \
      "hosts/${FLAKE_HOST}/configuration/hardware-configuration.nix" && \
    git -c user.name=installer -c user.email=installer@localhost commit -q \
      -m "${FLAKE_HOST}: install-time hardware-configuration.nix" \
  ) || fatal "Failed to commit hardware-configuration.nix in ${REPO_DIR}."
}

# ──────────────────────────────────────────────────────────────
# Provision the local private companion (infra-nix-config-private)
# ──────────────────────────────────────────────────────────────
# The flake currently fetches `inputs.private` from GitHub. This local
# companion supports private-overlay editing/sync workflows. The legacy
# metadata loader cannot reach it during normal store-backed flake evaluation.
# The stub fallback is retained for a future local-input override, but does
# not currently replace the authenticated GitHub input; see TODO.md.
#
# Strategy (tiered cascade, first success wins):
#   A. Sibling already present at the target path (user pre-staged via
#      SSH/USB) → leave it alone.
#   B. `gh` already authenticated in the live ISO shell (user logged in
#      before invoking install.sh) → `gh repo clone`.
#   C. Offer interactive `gh auth login -w` (web/device-code flow,
#      30-second timeout, default no for unattended installs); on success,
#      `gh repo clone`.
#   D. Write a stub git repo containing just
#      `hosts/<HOST>/user-settings.nix = { }` and commit it for the retained
#      local-companion workflow. A future input override can use this stub.
#
# A previous "unauthenticated public HTTPS clone" tier was removed: the
# underlying repo is private, so the clone always returned HTTP 401 and
# git's credential helper hung waiting for a TTY username/password (with
# our `2>/dev/null` muffle even hiding the prompt). Tiers B/C already
# handle every authenticated case. As a defence-in-depth we also export
# `GIT_TERMINAL_PROMPT=0` for the entire function so any stray git auth
# prompt fails fast instead of blocking.
#
# Side effect: sets PRIVATE_SIBLING_KIND to "real" or "stub" so
# post_install() can tailor its next-steps blurb. Upgrade path from
# stub → real lives in postinstall.sh's `step_private_overlay()`.
PRIVATE_SIBLING_KIND="unknown"

provision_private_sibling() {
  local private_dir="/mnt/home/${USERNAME}/git/infra-nix-config-private"
  local repo_slug="elvismercado/infra-nix-config-private"

  # Defence in depth: any git invocation under this function that would
  # otherwise prompt on the TTY (e.g. private-repo HTTPS without creds)
  # exits non-zero immediately instead of hanging silently.
  export GIT_TERMINAL_PROMPT=0

  # Up-front explanation so the user knows what to expect across the
  # entire cascade, before any potentially-long nix-shell fetches.
  echo ""
  echo "  ─── Private companion provisioning ───"
  echo "  The local companion repository is ${repo_slug}."
  echo "  Cascade (first success wins):"
  echo "    A) pre-staged sibling at ${private_dir}"
  echo "    B) gh CLI already authenticated in this shell"
  echo "    C) interactive gh auth login (web/device-code flow)"
  echo "    D) stub fallback (Europe/London + en-GB until upgraded later)"
  echo ""

  # Tier A — already on disk.
  info "[Tier A] Checking for a pre-staged sibling at ${private_dir}..."
  if [[ -d "$private_dir" ]]; then
    info "[Tier A] Found — leaving it alone."
    PRIVATE_SIBLING_KIND="real"
    return 0
  fi
  info "[Tier A] Not present, continuing."

  mkdir -p "$(dirname "$private_dir")"

  # Tier B — gh already authenticated in this shell.
  # First nix-shell call may take a minute on a fresh ISO to fetch the
  # gh closure (~30 MB) — DO NOT redirect stderr, so the user sees nix's
  # copy-path lines and knows the script is alive. Only `gh auth
  # status`'s own stdout is muted because we just care about the exit
  # code.
  info "[Tier B] Checking gh authentication (may fetch the gh closure on first run)..."
  if nix-shell -p gh git --run "gh auth status" >/dev/null; then
    info "[Tier B] gh is authenticated — cloning private sibling..."
    if nix-shell -p gh git --run "gh repo clone '${repo_slug}' '${private_dir}'"; then
      info "[Tier B] Cloned successfully."
      PRIVATE_SIBLING_KIND="real"
      chown -R "${USER_UID}:100" "$private_dir" \
        || fatal "Failed to chown ${private_dir} to ${USER_UID}:100."
      return 0
    fi
    warn "[Tier B] gh repo clone failed despite authenticated session — falling through."
  else
    info "[Tier B] gh is not authenticated in this shell."
  fi

  # Tier C — offer interactive gh auth + clone.
  # 30-second default-no keeps unattended installs from hanging.
  echo ""
  printf "  [Tier C] Authenticate with GitHub now (web/device-code flow)? [y/N] (auto-skip in 30s): "
  local answer=""
  if read -r -t 30 answer; then :; else echo ""; fi
  case "${answer:-n}" in
    [yY]|[yY][eE][sS])
      info "[Tier C] Launching gh auth login (web/device-code flow)..."
      if nix-shell -p gh git --run "gh auth login -h github.com -p https -w"; then
        info "[Tier C] Authenticated — cloning private sibling..."
        if nix-shell -p gh git --run "gh repo clone '${repo_slug}' '${private_dir}'"; then
          info "[Tier C] Cloned successfully."
          PRIVATE_SIBLING_KIND="real"
          chown -R "${USER_UID}:100" "$private_dir" \
            || fatal "Failed to chown ${private_dir} to ${USER_UID}:100."
          return 0
        else
          warn "[Tier C] gh repo clone failed after authentication — falling through to stub."
        fi
      else
        warn "[Tier C] gh auth login failed or was cancelled — falling through to stub."
      fi
      ;;
    *)
      info "[Tier C] Skipped interactive GitHub authentication."
      ;;
  esac

  # Tier D — retained local stub fallback.
  info "[Tier D] Writing local stub companion. Upgrade later via postinstall."

  nix-shell -p git --run "
    set -e
    git init -q -b main '${private_dir}'
    mkdir -p '${private_dir}/hosts/${FLAKE_HOST}'
    printf '%s\n' '{ }' > '${private_dir}/hosts/${FLAKE_HOST}/user-settings.nix'
    cat > '${private_dir}/README.md' <<'STUB_README'
# infra-nix-config-private (stub)

Auto-generated by scripts/nixos/install.sh because the real private repo
wasn't reachable during install. This retained local stub preserves the
editing shape for a planned offline input override. The current GitHub private
flake input and legacy metadata loader do not consume this stub; see the public
TODO.md before relying on it for a no-access install.

The stub's hosts/<HOST>/user-settings.nix returns { }, so the local overlay
is intentionally empty.

To replace this stub with the real overlay (assuming you have access):

    cd ~/git
    rm -rf infra-nix-config-private
    gh repo clone elvismercado/infra-nix-config-private

\`postinstall.sh\` offers this as an interactive step.
STUB_README
    cd '${private_dir}'
    git -c user.name=installer -c user.email=installer@localhost add -A
    git -c user.name=installer -c user.email=installer@localhost commit -q -m 'initial stub (auto-generated by install.sh)'
  " || fatal "Failed to write stub private sibling at ${private_dir}."

  info "[Tier D] Stub written and committed."
  PRIVATE_SIBLING_KIND="stub"
  chown -R "${USER_UID}:100" "$private_dir" \
    || fatal "Failed to chown ${private_dir} to ${USER_UID}:100."
}

# ──────────────────────────────────────────────────────────────
# Install NixOS
# ──────────────────────────────────────────────────────────────
install_nixos() {
  info "Installing NixOS with flake configuration '${FLAKE_HOST}'..."
  info "This may take a while (15–60 minutes depending on your internet connection)..."
  echo ""

  # Run from inside the deployed repo so the committed install-time hardware
  # configuration is the flake source. The private input remains GitHub-backed;
  # the local companion or stub does not override it yet (see TODO.md).
  # Subshell so set -e propagates the failure without changing the caller's CWD.
  ( cd "${REPO_DIR}" && \
    nixos-install --flake ".#${FLAKE_HOST}" --no-root-passwd \
      --option download-buffer-size 268435456 )
}

# ──────────────────────────────────────────────────────────────
# Install Report
# ──────────────────────────────────────────────────────────────
write_report() {
  local report="${REPO_DIR}/hosts/${FLAKE_HOST}/INSTALL-REPORT.md"
  local hw_config="${REPO_DIR}/hosts/${FLAKE_HOST}/configuration/hardware-configuration.nix"
  local elapsed=$SECONDS

  info "Writing install report to ${report}..."

  cat > "$report" <<REPORT
# Install Report — ${FLAKE_HOST}

**Date:** $(date '+%Y-%m-%d %H:%M:%S %Z')
**Duration:** $((elapsed / 60))m $((elapsed % 60))s

## Configuration

| Setting | Value |
|---------|-------|
| Host | ${FLAKE_HOST} |
| User | ${USERNAME} |
| Repo | ${REPO_DIR} |
| Flake URL | ${FLAKE_REPO} |

## Disk Layout

| Setting | Value |
|---------|-------|
| OS Disk | ${DISK} |
| EFI Size | ${EFI_SIZE} |
| Swap Size | ${SWAP_SIZE} |
| Home Disk | ${HOME_DISK:-— (none)} |
| Home Size | ${HOME_SIZE:-— (entire disk or none)} |
| Keep Home | ${KEEP_HOME:-no} |

### OS Disk Partitions

\`\`\`
$(lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS "$DISK" 2>/dev/null || echo "N/A")
\`\`\`

REPORT

  if [[ -n "$HOME_DISK" ]]; then
    cat >> "$report" <<REPORT
### Home Disk Partitions

\`\`\`
$(lsblk -o NAME,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS "$HOME_DISK" 2>/dev/null || echo "N/A")
\`\`\`

REPORT
  fi

  cat >> "$report" <<REPORT
## Hardware Configuration

\`\`\`nix
$(cat "$hw_config" 2>/dev/null || echo "N/A")
\`\`\`
REPORT

  info "Install report saved."
}

# ──────────────────────────────────────────────────────────────
# Post-install
# ──────────────────────────────────────────────────────────────
post_install() {
  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║              Installation complete!                     ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  info "Next steps:"
  echo ""
  echo "  1. Reboot into your new system:"
  echo "     # reboot"
  echo ""
  echo "  2. Log in as '${USERNAME}' with password '${USERNAME}'"
  echo "     (set by initialPassword in user.nix)"
  echo ""
  echo "  3. Run the post-install script:"
  echo "     \$ postinstall"
  echo "     (or: bash ~/git/${REPO_NAME}/scripts/nixos/postinstall.sh)"
  echo ""
  echo "     It will guide you through:"
  echo "     - Changing your password"
  echo "     - Setting up git identity and SSH keys"
  echo "     - GitHub authentication"
  if [[ "${PRIVATE_SIBLING_KIND}" == "stub" ]]; then
    echo "     - Replacing the stub private sibling with the real repo"
  fi
  echo "     - Verifying NixOS and home-manager rebuilds"
  echo "     - Committing hardware-configuration.nix"
  echo ""
  if [[ "${PRIVATE_SIBLING_KIND}" == "stub" ]]; then
    echo "  Note: a local infra-nix-config-private stub was provisioned next to"
    echo "  infra-nix-config. Replace it during postinstall for editing/sync"
    echo "  workflows. The GitHub-backed private flake input still requires access."
    echo "  Manual command: gh repo clone elvismercado/infra-nix-config-private"
    echo ""
  else
    echo "  Note: the real infra-nix-config-private companion was cloned next to"
    echo "  infra-nix-config."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}NixOS Installer${NC}"
  echo ""

  check_preconditions
  parse_args "$@"
  clone_repo
  validate_host
  interactive_config

  validate_disk_capacity
  confirm_destroy
  unmount_disk
  wipe_disk_signatures
  partition_disk
  format_partitions
  mount_partitions
  deploy_repo
  provision_private_sibling
  generate_hardware_config
  install_nixos
  write_report
  post_install
}

main "$@"
