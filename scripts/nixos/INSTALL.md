# Installing NixOS

Step-by-step guide to install NixOS from scratch using the ext4 disk layout
and this flake configuration. Works with any NixOS host defined in the flake
(e.g. JIN, or any future host you add under `hosts/`).

For host-specific hardware details, see the README in your host's directory
(e.g. `hosts/JIN/README.md`).

---

## Prerequisites

| Requirement     | Details                                                         |
| --------------- | --------------------------------------------------------------- |
| **Boot media**  | NixOS 25.11 ISO (minimal or graphical) booted from USB          |
| **Internet**    | Wired (DHCP) or Wi-Fi via `nmtui`                               |
| **Target disk** | 1 or 2 disks — **all data on target disk(s) will be erased**    |
| **Root space**  | At least 20 GiB for root (`/nix/store` grows with generations)  |
| **This flake**  | Public repo — cloned automatically during install               |
| **Host config** | A host directory under `hosts/<HOST>/` with `user-settings.nix` |

> Download the ISO from <https://nixos.org/download/#nixos-iso>.
> Write it to USB with Etcher, USBImager, or `dd`.

---

## Quick install (automated)

Boot the NixOS installer and open a terminal.

**Become root:**

```bash
sudo -i
```

**Authenticate with GitHub and clone the repo:**

```bash
nix-shell -p gh git --run '
  gh auth login -h github.com -p https -w &&
  gh repo clone elvismercado/infra-nix-config /tmp/infra-nix-config
'
```

> `gh auth login` is currently required for the private GitHub flake input
> and lets `install.sh` clone the local companion
> (`elvismercado/infra-nix-config-private`). The retained local stub does
> not yet replace that input; the offline flow is tracked in `TODO.md`.

**Run the installer (interactive — prompts for host, disks, and sizes):**

```bash
bash /tmp/infra-nix-config/scripts/nixos/install.sh
```

> **Interactive mode**: Run with no arguments and the script will prompt for
> each value with examples. Any flags you provide on the command line are
> used as-is — only missing values are prompted.

> The `--host` name must match a NixOS host directory under `hosts/` (i.e.
> one whose `user-settings.nix` has a `linux` system). Darwin hosts like
> EDGE are not valid targets.

### Examples with flags

**2-drive install — OS on first disk, /home on second disk:**

```bash
bash /tmp/infra-nix-config/scripts/nixos/install.sh /dev/nvme0n1 \
  --host JIN --efi-size 2G --swap-size 48G \
  --home-disk /dev/nvme1n1
```

**Reinstall OS but keep existing /home data on second drive:**

```bash
bash /tmp/infra-nix-config/scripts/nixos/install.sh /dev/nvme0n1 \
  --host JIN --efi-size 2G --swap-size 48G \
  --home-disk /dev/nvme1n1 --keep-home
```

**Single-disk install — no separate /home:**

```bash
bash /tmp/infra-nix-config/scripts/nixos/install.sh /dev/nvme0n1 \
  --host JIN --efi-size 2G --swap-size 48G
```

**Single-disk install — with /home partition:**

```bash
bash /tmp/infra-nix-config/scripts/nixos/install.sh /dev/sda \
  --host MYHOST --efi-size 512M --swap-size 16G \
  --home-size 200G
```

> **`--keep-home`**: Use with `--home-disk` to mount an existing /home
> partition without reformatting. The OS disk is wiped; the home disk is
> preserved. In interactive mode, the script asks whether to format when
> you select a dedicated home disk (default: keep existing data).

The script will:

1. Clone the repo and auto-detect the username from `hosts/<HOST>/user-settings.nix`
2. Show a full configuration summary and require you to type `yes` before any destructive action
3. Partition the OS disk (GPT: EFI + root + swap)
4. Partition the home disk, if provided — or mount it as-is with `--keep-home`
5. Format and mount everything under `/mnt`
6. Deploy the flake repo to `/mnt/home/<user>/git/infra-nix-config`
7. Generate `hardware-configuration.nix` for the current machine
8. Run `nixos-install --flake …#<HOST>`

After completion, reboot and log in with the username from
`user-settings.nix`. The initial password equals the username (set by
`initialPassword = userSettings.username` in `user.nix`). Change it
immediately with `passwd`.

---

## Manual step-by-step install

Follow these steps if you prefer to run each command yourself, or if the
automated script doesn't suit your setup.

### 0. Define your variables

Set these once — all subsequent commands reference them:

```bash
HOST=JIN                  # flake host name (must match a NixOS host under hosts/)
DISK=/dev/nvme0n1         # OS disk
HOME_DISK=/dev/nvme1n1    # (optional) dedicated /home disk — leave empty if single-disk
EFI_SIZE=2GiB             # EFI partition size
SWAP_SIZE=48GiB           # swap partition size
# HOME_SIZE=200GiB        # uncomment if using single-disk with /home partition
```

> Adjust all values for your machine. Use `lsblk -o NAME,SIZE,MODEL` to
> identify your disk(s). Sizes use `parted`-compatible units (e.g. `2GiB`,
> `512MiB`); MiB-aligned offsets are derived from these in Step 4.

### 1. Boot and become root

Boot from the NixOS USB and open a terminal.

```bash
sudo -i
```

> On the graphical ISO, open Konsole (Plasma) or Terminal (GNOME).
> On the minimal ISO, you're already at a root shell.

### 2. Set up networking

Wired connections should work automatically via DHCP. Verify with:

```bash
ping -c 3 nixos.org
```

For Wi-Fi, use the interactive NetworkManager TUI:

```bash
nmtui
```

### 3. Identify the target disk(s)

```bash
lsblk -o NAME,SIZE,MODEL
```

Confirm the variables you set in Step 0 match the correct disks.

### 3.5. Unmount any existing partitions

If the target disk(s) have existing partitions that are mounted, unmount
them first:

```bash
umount -R /mnt 2>/dev/null || true
for part in "${DISK}"*; do
  umount "$part" 2>/dev/null || true
  swapoff "$part" 2>/dev/null || true
done
if [[ -n "$HOME_DISK" ]]; then
  for part in "${HOME_DISK}"*; do
    umount "$part" 2>/dev/null || true
  done
fi
```

### 3.6. Wipe disk signatures

Erase stale filesystem, RAID, and LVM signatures to prevent I/O errors
during partitioning:

```bash
wipefs --all --force "$DISK"

# Only if using a dedicated home disk (and NOT --keep-home):
if [[ -n "$HOME_DISK" ]]; then
  wipefs --all --force "$HOME_DISK"
fi
```

### 4. Partition the disks

Create a GPT partition table with the ext4 layout.

#### OS disk

Compute the swap start position using absolute MiB offsets (avoids
alignment warnings from negative parted offsets on disks whose total
size is not an exact MiB multiple). The MiB values are derived from the
`*_SIZE` variables in Step 0 — mirroring how `install.sh` does it via
`size_mib()`.

```bash
# Strip GiB/MiB suffix and convert to MiB
SWAP_MIB=$(numfmt --from=iec --to-unit=Mi "${SWAP_SIZE%i*}B")
DISK_MIB=$(( $(blockdev --getsize64 "$DISK") / 1048576 ))
SWAP_START=$(( DISK_MIB - SWAP_MIB ))
```

| #   | Partition | Start       | End         | Size      |
| --- | --------- | ----------- | ----------- | --------- |
| 1   | EFI       | 1 MiB       | $EFI_SIZE   | EFI_SIZE  |
| 2   | Root      | $EFI_SIZE   | $SWAP_START | Remainder |
| 3   | Swap      | $SWAP_START | 100%        | SWAP_SIZE |

```bash
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB "$EFI_SIZE"
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart root ext4 "$EFI_SIZE" "${SWAP_START}MiB"
parted -s "$DISK" -- mkpart swap linux-swap "${SWAP_START}MiB" 100%

# Let the kernel re-read the partition table and wait for udev
partprobe "$DISK" 2>/dev/null || true
udevadm settle --timeout=30
```

#### Dedicated home disk (if using 2 drives)

| #   | Partition | Start | End  | Size        |
| --- | --------- | ----- | ---- | ----------- |
| 1   | Home      | 1 MiB | 100% | Entire disk |

```bash
parted -s "$HOME_DISK" -- mklabel gpt
parted -s "$HOME_DISK" -- mkpart home ext4 1MiB 100%

partprobe "$HOME_DISK" 2>/dev/null || true
udevadm settle --timeout=30
```

> **Keep existing /home (`--keep-home` equivalent):** If you want to
> preserve existing data on the home disk, skip this step entirely — do
> not create a partition table or format. Jump to Step 5 (skip the home
> format) and Step 6 (mount by device path instead of by-label).

#### Alternative: single-disk with /home partition

If you only have one disk and want a separate `/home` partition, derive
`HOME_MIB` from `HOME_SIZE` the same way as `SWAP_MIB`:

```bash
HOME_MIB=$(numfmt --from=iec --to-unit=Mi "${HOME_SIZE%i*}B")
SWAP_MIB=$(numfmt --from=iec --to-unit=Mi "${SWAP_SIZE%i*}B")
DISK_MIB=$(( $(blockdev --getsize64 "$DISK") / 1048576 ))
SWAP_START=$(( DISK_MIB - SWAP_MIB ))
HOME_START=$(( DISK_MIB - SWAP_MIB - HOME_MIB ))

parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB "$EFI_SIZE"
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart root ext4 "$EFI_SIZE" "${HOME_START}MiB"
parted -s "$DISK" -- mkpart home ext4 "${HOME_START}MiB" "${SWAP_START}MiB"
parted -s "$DISK" -- mkpart swap linux-swap "${SWAP_START}MiB" 100%

partprobe "$DISK" 2>/dev/null || true
udevadm settle --timeout=30
```

Verify the layout:

```bash
lsblk "$DISK"
lsblk "$HOME_DISK"   # if using 2 drives
```

### 5. Format the partitions

NVMe partitions are named `p1`, `p2`, etc. SATA drives use `1`, `2`, etc.

> `mkfs.ext4 -F` forces formatting even if `wipefs` left signatures behind —
> matches `install.sh`. Omit `-F` if you want a confirmation prompt.

#### 2-drive setup

```bash
mkfs.fat -F 32 -n BOOT "${DISK}p1"
mkfs.ext4 -F -L nixos "${DISK}p2"
mkswap -L swap "${DISK}p3"
mkfs.ext4 -F -L home "${HOME_DISK}p1"
```

> **Keep existing /home:** Skip the `mkfs.ext4 -F -L home` command above.
> The existing data and label on the home disk are preserved.

#### Single-disk without /home

```bash
mkfs.fat -F 32 -n BOOT "${DISK}p1"
mkfs.ext4 -F -L nixos "${DISK}p2"
mkswap -L swap "${DISK}p3"
```

#### Single-disk with /home

```bash
mkfs.fat -F 32 -n BOOT "${DISK}p1"
mkfs.ext4 -F -L nixos "${DISK}p2"
mkfs.ext4 -F -L home "${DISK}p3"
mkswap -L swap "${DISK}p4"
```

### 6. Mount the file systems

```bash
# Root
mount /dev/disk/by-label/nixos /mnt

# EFI
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot

# Home (if using separate home partition or second disk)
mkdir -p /mnt/home
mount /dev/disk/by-label/home /mnt/home

# Swap
swapon /dev/disk/by-label/swap
```

> **Keep existing /home:** If you skipped formatting the home disk, mount
> it by device path instead of by-label (the label may not be `home`):
>
> ```bash
> mkdir -p /mnt/home
> mount "${HOME_DISK}p1" /mnt/home    # NVMe; use "${HOME_DISK}1" for SATA
> ```

Verify everything is mounted:

```bash
findmnt --real
```

### 7. Clone the flake repository

Clone the repo, then look up the username from `user-settings.nix`:

```bash
REPO_NAME=infra-nix-config
nix-shell -p gh git --run "gh repo clone elvismercado/infra-nix-config /tmp/${REPO_NAME}"

# Read the username and UID for this host
TARGET_USER=$(sed -n 's/.*username[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "/tmp/${REPO_NAME}/hosts/${HOST}/user-settings.nix")
TARGET_UID=$(sed -n 's/.*uid[[:space:]]*=[[:space:]]*\([0-9]\+\).*/\1/p' "/tmp/${REPO_NAME}/hosts/${HOST}/user-settings.nix")
TARGET_UID="${TARGET_UID:-1000}" # default to 1000 if uid not set
echo "Resolved user: $TARGET_USER (UID $TARGET_UID)"
```

Deploy to the target user's home directory:

```bash
REPO_DIR="/mnt/home/${TARGET_USER}/git/${REPO_NAME}"
mkdir -p "$(dirname "$REPO_DIR")"
cp -a "/tmp/${REPO_NAME}" "$REPO_DIR"
chown -R "${TARGET_UID}:100" "/mnt/home/${TARGET_USER}"
rm -rf "/tmp/${REPO_NAME}"
```

> **Keep existing /home:** Only chown the `git` directory to avoid a slow
> recursive chown across all existing user data:
>
> ```bash
> chown -R "${TARGET_UID}:100" "/mnt/home/${TARGET_USER}/git"
> ```

### 7.5. Provision the local private companion

The flake fetches `inputs.private` from the private GitHub repository
`elvismercado/infra-nix-config-private`. A sibling checkout supports private
overlay editing and sync workflows. It does not currently feed the legacy
metadata loader during normal flake evaluation. The retained stub below does
not override the GitHub input; both gaps are tracked in `TODO.md`.

**If you have access to the real private repo**, clone it next to the
public one (HTTPS works for the owner with cached credentials; otherwise
use SSH or pre-stage via USB/SSH before reaching this step):

```bash
PRIVATE_DIR="/mnt/home/${TARGET_USER}/git/infra-nix-config-private"
nix-shell -p git --run "git clone https://github.com/elvismercado/infra-nix-config-private.git '$PRIVATE_DIR'"
chown -R "${TARGET_UID}:100" "$PRIVATE_DIR"
```

**If the companion clone is unavailable**, the retained flow writes a local
stub with an empty `user-settings.nix` for this host. This preserves the local
editing shape for a future input override, but does not currently make a
no-access installation succeed.

```bash
PRIVATE_DIR="/mnt/home/${TARGET_USER}/git/infra-nix-config-private"
nix-shell -p git --run "
  set -e
  git init -q -b main '$PRIVATE_DIR'
  mkdir -p '$PRIVATE_DIR/hosts/${HOST}'
  printf '%s\n' '{ }' > '$PRIVATE_DIR/hosts/${HOST}/user-settings.nix'
  cd '$PRIVATE_DIR'
  git -c user.name=installer -c user.email=installer@localhost add -A
  git -c user.name=installer -c user.email=installer@localhost commit -q -m 'initial stub'
"
chown -R "${TARGET_UID}:100" "$PRIVATE_DIR"
```

> The stub remains an initialised, committed git repository for the planned
> local-input override. The current `github:` input does not consume it.

To upgrade a stub later (after first boot + `gh auth login`):

```bash
cd ~/git
rm -rf infra-nix-config-private
gh repo clone elvismercado/infra-nix-config-private
```

`postinstall.sh` offers this as an interactive step.

### 8. Generate hardware configuration

This detects your current mounts, UUIDs, and kernel modules:

```bash
nixos-generate-config --show-hardware-config --root /mnt \
  > "${REPO_DIR}/hosts/${HOST}/configuration/hardware-configuration.nix"
```

Review the output to confirm the file systems and swap are detected:

```bash
cat "${REPO_DIR}/hosts/${HOST}/configuration/hardware-configuration.nix"
```

You should see entries for `/`, `/boot`, optionally `/home`, and a swap device.

### 9. Install NixOS

```bash
nixos-install --flake "${REPO_DIR}#${HOST}" --no-root-passwd \
  --option download-buffer-size 268435456
```

> `--no-root-passwd` skips the root password prompt. Your user's
> `initialPassword` is configured in `user.nix` — change it immediately
> after first boot.
>
> `--option download-buffer-size 268435456` increases the download buffer
> to 256 MiB (default is 64 MiB), preventing "download buffer is full"
> warnings during large closure fetches.

This downloads and builds the full system. Expect 15–60 minutes depending on
your internet speed and hardware.

### 10. Reboot

```bash
reboot
```

Remove the USB drive when prompted (or during BIOS post).

---

## Post-install

After rebooting, log in with your username. The initial password equals the
username (set by `initialPassword = userSettings.username` in `user.nix`).

### Post-install script (recommended)

Run the interactive post-install script to complete setup. It guides you
through all remaining steps — each one is optional and can be skipped:

```bash
postinstall
```

Or run it directly:

```bash
bash ~/git/infra-nix-config/scripts/nixos/postinstall.sh
```

The script handles:

1. Changing your user password (default is insecure)
2. Setting a root password (optional)
3. Configuring git identity (real name and email)
4. Generating an SSH key (ed25519, with hostname + timestamp comment)
5. Authenticating with GitHub (`gh auth login`)
6. Adding the SSH key to GitHub
7. Replacing a local private stub with the real companion repository
8. Verifying a NixOS rebuild (`nixos-rebuild switch`)
9. Committing and pushing `hardware-configuration.nix`

The script is safe to re-run — it detects what's already done and skips
completed steps.

### Manual steps (alternative)

If you prefer to run the steps manually:

```bash
# Change your password
passwd

# (Optional) Set a root password
sudo passwd root

# Verify the system rebuilds
cd ~/git/infra-nix-config
sudo nixos-rebuild switch --flake .#$HOST

# Commit the hardware configuration
git add hosts/$HOST/configuration/hardware-configuration.nix
git commit -m "$HOST: update hardware-configuration.nix"
git push
```

### Private metadata companion (locally cloned, stub retained on failure)

The flake declares `infra-nix-config-private` as a private GitHub
`flake = false` input. It holds PII-bearing per-host fields (Syncthing device
IDs, LAN addresses, `timeZone`, `language`, `regionalFormat`). The input
currently supplies private user settings and secrets. The local sibling
checkout supports editing and sync; private metadata loading remains deferred
in `TODO.md`.

`install.sh` provisions a sibling automatically using a tiered cascade
(first success wins):

1. **Pre-staged**: a sibling already at
  `/mnt/home/<user>/git/infra-nix-config-private` (e.g. copied in via SSH/USB
   before `install.sh`) is left alone.
2. **`gh` already authenticated**: if `gh auth status` succeeds in the
   live ISO shell — i.e. you ran `nix-shell -p gh --run "gh auth login -w"`
   before invoking `install.sh` — the installer uses
  `gh repo clone elvismercado/infra-nix-config-private`.
3. **Interactive `gh auth login`**: the installer prompts (30-second
   default-no, so unattended installs don't hang) to authenticate with
   GitHub via the web/device-code flow. You'll get a one-time code to
   paste into a browser on any other device. On success it clones the
   real repo.
4. **Stub fallback**: writes an initialised git repo containing
   `hosts/<HOST>/user-settings.nix = { }` and a stub README, then
  commits it. This retains the expected local shape for a future input
  override, but does not replace the current GitHub flake input.

`install.sh` exports `GIT_TERMINAL_PROMPT=0` for the cascade so any
stray git auth prompt fails fast instead of hanging on a hidden TTY
prompt. It also prints `[Tier X]` info lines around every step so
silent `nix-shell` cache fetches don't look like a hang.

If tiers 1-3 succeed, the local companion is ready. If the cascade lands on
the stub, replace it with the real companion after first boot. Private GitHub
access is still required by the current flake input either way:

```bash
cd ~/git
rm -rf infra-nix-config-private
gh repo clone elvismercado/infra-nix-config-private
# Commit and push private changes before refreshing the locked input.
```

`postinstall.sh` includes an interactive step (`step_private_overlay`)
for this upgrade after `gh auth login`.

---

## Troubleshooting

### Wrong disk or partition layout

If you selected the wrong disk, reboot from the USB and start over. The
installer does not touch disks other than the one you specify.

### Boot failure after install

1. Boot from the USB again
2. Mount the installed system:
   ```bash
   mount /dev/disk/by-label/nixos /mnt
   mount /dev/disk/by-label/BOOT /mnt/boot
   mount /dev/disk/by-label/home /mnt/home   # if using separate /home
   ```
3. Enter the installed system:
   ```bash
   nixos-enter --root /mnt
   ```
4. Fix the configuration and rebuild:
   ```bash
  cd /home/$TARGET_USER/git/infra-nix-config
   nixos-rebuild switch --flake .#$HOST
   ```
5. Exit and reboot:
   ```bash
   exit
   reboot
   ```

### Regenerate hardware configuration

If you change disks or partitions after install:

```bash
nixos-generate-config --show-hardware-config \
  > ~/git/infra-nix-config/hosts/$HOST/configuration/hardware-configuration.nix

sudo nixos-rebuild switch --flake .#$HOST
```

### GRUB not showing or boot entry missing

If the EFI boot entry is missing, boot from USB and:

```bash
mount /dev/disk/by-label/nixos /mnt
mount /dev/disk/by-label/BOOT /mnt/boot
nixos-enter --root /mnt
nixos-rebuild boot --flake /home/$TARGET_USER/git/infra-nix-config#$HOST
exit
reboot
```

### Rolling back

GRUB keeps previous generations. At the boot menu, select
**NixOS — All configurations** and pick an older generation.

From a running system:

```bash
sudo nixos-rebuild switch --rollback
```

---

## Disk layout reference — 2-drive setup

### Drive 1 — OS

```
┌──────────────────────────────────────────────────────────┐
│                    OS disk                               │
├──────────┬───────────────────────────────────┬───────────┤
│ p1: EFI  │ p2: Root (/)                      │ p3: Swap  │
│ EFI_SIZE │ remainder                         │ SWAP_SIZE │
│ FAT32    │ ext4                              │ linux-swap│
│ /boot    │ /                                 │           │
└──────────┴───────────────────────────────────┴───────────┘
```

### Drive 2 — Home

```
┌──────────────────────────────────────────────────────────┐
│                    Home disk                             │
├──────────────────────────────────────────────────────────┤
│ p1: Home (/home)                                        │
│ entire disk                                             │
│ ext4                                                    │
│ /home                                                   │
└──────────────────────────────────────────────────────────┘
```

## Disk layout reference — single disk

### Without /home

```
┌──────────────────────────────────────────────────────────┐
│                    OS disk                               │
├──────────┬───────────────────────────────────┬───────────┤
│ p1: EFI  │ p2: Root (/)                      │ p3: Swap  │
│ EFI_SIZE │ remainder                         │ SWAP_SIZE │
│ FAT32    │ ext4                              │ linux-swap│
│ /boot    │ /                                 │           │
└──────────┴───────────────────────────────────┴───────────┘
```

### With /home

```
┌──────────────────────────────────────────────────────────────────┐
│                      OS disk                                    │
├──────────┬───────────────────┬──────────────────┬───────────────┤
│ p1: EFI  │ p2: Root (/)      │ p3: Home (/home) │ p4: Swap      │
│ EFI_SIZE │ remainder         │ HOME_SIZE        │ SWAP_SIZE     │
│ FAT32    │ ext4              │ ext4             │ linux-swap    │
│ /boot    │ /                 │ /home            │               │
└──────────┴───────────────────┴──────────────────┴───────────────┘
```

---

## See also

- [NIXOS.md](../../NIXOS.md) — NixOS system configuration, modules, adding hosts
- [NixOS Manual — Installation](https://nixos.org/manual/nixos/stable/#sec-installation)
