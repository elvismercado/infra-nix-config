#!/usr/bin/env bash
# postinstall.sh — Interactive post-install setup for NixOS
#
# Run this after rebooting into a freshly installed NixOS system.
# Every step is optional and can be skipped.
#
# Usage:
#   bash ~/git/infra-nix-config/scripts/nixos/postinstall.sh
#   # or use the 'postinstall' shell alias

set -euo pipefail

SECONDS=0

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[postinstall]${NC} $*"; }
warn()  { echo -e "${YELLOW}[postinstall]${NC} $*"; }
error() { echo -e "${RED}[postinstall]${NC} $*" >&2; }

trap 'elapsed=$SECONDS; printf "\n%b Total time: %dm %ds\n" "${BOLD}[postinstall]${NC}" $((elapsed/60)) $((elapsed%60))' EXIT

# Prompt with [y/N] default. Returns 0 for yes, 1 for no.
confirm() {
  local prompt="$1"
  local answer
  read -rp "$(echo -e "${BOLD}${prompt}${NC} [y/N]: ")" answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# ──────────────────────────────────────────────────────────────
# Detect environment
# ──────────────────────────────────────────────────────────────
detect_environment() {
  HOST=$(hostname)

  # Derive REPO_DIR from the script's own location: scripts/nixos/postinstall.sh
  # → repo root is three levels up. This honours whatever path the user chose
  # in userSettings.repoPath without re-parsing the file.
  local script_path
  script_path=$(readlink -f "$0") \
    || { error "Could not resolve script path via readlink."; exit 1; }
  REPO_DIR=$(cd "$(dirname "$script_path")/../.." && pwd) \
    || { error "Could not derive REPO_DIR from script path: $script_path"; exit 1; }
  REPO_NAME=$(basename "$REPO_DIR")

  if [[ ! -d "$REPO_DIR" ]]; then
    error "Config repo not found at ${REPO_DIR}"
    error "Expected the infra-nix-config repo to be cloned during install."
    exit 1
  fi

  if [[ ! -d "${REPO_DIR}/hosts/${HOST}" ]]; then
    error "Hostname '${HOST}' does not match any flake host."
    error "Available hosts:"
    for dir in "${REPO_DIR}"/hosts/*/; do
      [[ -d "$dir" ]] && echo "  - $(basename "$dir")"
    done
    error "Check that networking.hostName matches the hosts/ directory name."
    exit 1
  fi

  info "Host:     ${BOLD}${HOST}${NC}"
  info "User:     ${BOLD}${USER}${NC}"
  info "Repo:     ${BOLD}${REPO_DIR}${NC}"
  echo ""
}

# ──────────────────────────────────────────────────────────────
# Step 1: Change user password
# ──────────────────────────────────────────────────────────────
step_change_password() {
  warn "Your password is currently set to your username (insecure)."
  if confirm "Change your password now?"; then
    passwd
    echo ""
  else
    warn "Skipped — remember to change it later with: passwd"
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 2: Set root password
# ──────────────────────────────────────────────────────────────
step_root_password() {
  if confirm "Set a root password?"; then
    sudo passwd root
    echo ""
  else
    info "Skipped."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 3: Configure git identity
# ──────────────────────────────────────────────────────────────
step_git_identity() {
  local current_name current_email
  current_name=$(git config --global user.name 2>/dev/null || echo "")
  current_email=$(git config --global user.email 2>/dev/null || echo "")

  if [[ -n "$current_name" ]]; then
    info "Current git identity: ${BOLD}${current_name} <${current_email}>${NC}"
  else
    info "Git identity: not configured"
  fi

  if confirm "Configure git identity (name and email)?"; then
    local name email

    read -rp "  Full name: " name
    if [[ -n "$name" ]]; then
      git config --global user.name "$name"
      info "Set user.name = ${name}"
    fi

    read -rp "  Email: " email
    if [[ -n "$email" ]]; then
      git config --global user.email "$email"
      info "Set user.email = ${email}"
    fi
    echo ""
  else
    info "Skipped."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 4: Generate SSH key
# ──────────────────────────────────────────────────────────────
step_ssh_key() {
  local key_path="$HOME/.ssh/id_ed25519"

  if [[ -f "$key_path" ]]; then
    info "SSH key already exists at ${key_path}"
    if ! confirm "Generate a new key anyway? (overwrites existing)"; then
      info "Skipped."
      echo ""
      return
    fi
  else
    if ! confirm "Generate an SSH key (ed25519)?"; then
      info "Skipped."
      echo ""
      return
    fi
  fi

  local comment="${USER}@$(hostname)-$(date +%Y-%m-%d-%H%M)"
  info "Key comment: ${BOLD}${comment}${NC}"
  ssh-keygen -t ed25519 -C "$comment" -f "$key_path"
  echo ""
}

# ──────────────────────────────────────────────────────────────
# Step 5: Authenticate with GitHub
# ──────────────────────────────────────────────────────────────
step_gh_auth() {
  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    info "Already authenticated with GitHub."
    echo ""
    return
  fi

  if ! command -v gh &>/dev/null; then
    warn "gh CLI not found — skipping GitHub authentication."
    warn "Install it or add it to your packages, then run: gh auth login"
    echo ""
    return
  fi

  if confirm "Authenticate with GitHub (gh auth login)?"; then
    gh auth login
    echo ""
  else
    info "Skipped."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 6: Add SSH key to GitHub
# ──────────────────────────────────────────────────────────────
step_gh_ssh_key() {
  local key_path="$HOME/.ssh/id_ed25519.pub"

  if [[ ! -f "$key_path" ]]; then
    info "No SSH public key found — skipping GitHub SSH key upload."
    echo ""
    return
  fi

  if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
    warn "Not authenticated with GitHub — skipping SSH key upload."
    warn "Run 'gh auth login' first, then: gh ssh-key add ${key_path}"
    echo ""
    return
  fi

  info "SSH public key: ${key_path}"
  if confirm "Add this SSH key to your GitHub account?"; then
    gh ssh-key add "$key_path"
    info "SSH key added to GitHub."
    echo ""
  else
    info "Skipped."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 7: Replace stub private overlay with the real repo
# ──────────────────────────────────────────────────────────────
step_private_overlay() {
  local private_dir="$HOME/git/infra-nix-config-private"

  if [[ ! -d "$private_dir" ]]; then
    info "No private sibling at ${private_dir} — nothing to upgrade. Skipping."
    echo ""
    return
  fi

  # Already configured with a real origin? Treat as already upgraded.
  if git -C "$private_dir" remote get-url origin &>/dev/null; then
    info "Private sibling already has a configured remote — nothing to upgrade."
    echo ""
    return
  fi

  warn "Private sibling at ${private_dir} is the install.sh stub."
  warn "The local stub does not replace the GitHub-backed private flake input."

  if ! command -v gh &>/dev/null || ! gh auth status &>/dev/null; then
    warn "gh CLI not authenticated — cannot upgrade the stub automatically."
    warn "Run 'gh auth login' first, then re-run postinstall — or upgrade manually:"
    warn "  cd ~/git && rm -rf infra-nix-config-private && gh repo clone elvismercado/infra-nix-config-private"
    echo ""
    return
  fi

  if ! confirm "Replace the stub with the real elvismercado/infra-nix-config-private repo?"; then
    info "Skipped — stub remains in place."
    echo ""
    return
  fi

  # Move the stub aside so a failed clone can restore the local companion.
  local stub_backup
  stub_backup=$(mktemp -d -t infra-nix-config-private-stub.XXXXXX)
  info "Backing up stub to ${stub_backup}..."
  mv "$private_dir" "$stub_backup/infra-nix-config-private"

  if gh repo clone elvismercado/infra-nix-config-private "$private_dir"; then
    info "Real private sibling cloned. Removing stub backup..."
    rm -rf "$stub_backup"
    info "Done. Next rebuild will pick up real timezone / locale values."
  else
    error "gh repo clone failed. Restoring the stub from ${stub_backup}..."
    mv "$stub_backup/infra-nix-config-private" "$private_dir"
    rm -rf "$stub_backup"
    warn "Stub restored. Fix the auth issue and re-run postinstall, or upgrade manually:"
    warn "  cd ~/git && rm -rf infra-nix-config-private && gh repo clone elvismercado/infra-nix-config-private"
  fi
  echo ""
}

# ──────────────────────────────────────────────────────────────
# Step 7: Verify NixOS rebuild
# ──────────────────────────────────────────────────────────────
step_nixos_rebuild() {
  if confirm "Verify NixOS rebuild (sudo nixos-rebuild switch)?"; then
    cd "$REPO_DIR"
    info "Running: sudo nixos-rebuild switch --flake .#${HOST}"
    sudo nixos-rebuild switch --flake ".#${HOST}"
    info "NixOS rebuild succeeded."

    # Refresh PATH so newly-activated profile paths (including
    # home-manager CLI) are visible in this shell session.
    # Temporarily disable nounset — /etc/set-environment references
    # variables like XDG_STATE_HOME before they are defined.
    if [[ -f /etc/set-environment ]]; then
      set +u
      . /etc/set-environment
      set -u
    fi

    # /etc/set-environment does not include per-user profile paths.
    # home-manager CLI lives in /etc/profiles/per-user/$USER/bin.
    local per_user="/etc/profiles/per-user/${USER}/bin"
    if [[ -d "$per_user" ]] && [[ ":${PATH}:" != *":${per_user}:"* ]]; then
      export PATH="${per_user}:${PATH}"
    fi
    echo ""
  else
    info "Skipped."
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 8: Commit & push hardware-configuration.nix
# ──────────────────────────────────────────────────────────────
step_commit_hardware_config() {
  local hw_config="hosts/${HOST}/configuration/hardware-configuration.nix"

  cd "$REPO_DIR"

  # Working-tree changes (uncommitted edits or untracked file) take priority:
  # commit them first, then continue to the push check below.
  if ! git diff --quiet -- "$hw_config" \
     || ! git diff --cached --quiet -- "$hw_config" \
     || git ls-files --others --exclude-standard | grep -q "$hw_config"; then

    info "hardware-configuration.nix has uncommitted changes."
    if confirm "Commit hardware-configuration.nix?"; then
      git add "$hw_config"
      git commit -m "${HOST}: update hardware-configuration.nix"
    else
      info "Skipped commit."
      echo ""
      return
    fi
  fi

  # File is committed. Check if there are unpushed commits touching it
  # (install.sh makes a local-only commit during install, so this is the
  # common path for first-time hosts).
  if ! git remote get-url origin &>/dev/null; then
    info "hardware-configuration.nix is committed; no remote configured."
    echo ""
    return
  fi

  local upstream
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [[ -z "$upstream" ]]; then
    info "hardware-configuration.nix is committed; no upstream branch set — nothing to push."
    echo ""
    return
  fi

  if [[ -z "$(git log --oneline "${upstream}..HEAD" -- "$hw_config" 2>/dev/null)" ]]; then
    info "hardware-configuration.nix is already pushed — nothing to do."
    echo ""
    return
  fi

  info "hardware-configuration.nix is committed locally but not pushed."
  if confirm "Push to remote?"; then
    info "Pushing to remote..."
    git push
    info "Pushed successfully."
  else
    info "Skipped push."
  fi
  echo ""
}

# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}NixOS Post-Install Setup${NC}"
  echo ""

  if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root."
    error "Run as your normal user: bash <repo>/scripts/nixos/postinstall.sh (or use the 'postinstall' alias)."
    exit 1
  fi

  detect_environment

  step_change_password
  step_root_password
  step_git_identity
  step_ssh_key
  step_gh_auth
  step_gh_ssh_key
  step_private_overlay
  step_nixos_rebuild
  step_commit_hardware_config

  echo ""
  echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}${BOLD}║              Post-install setup complete!                ║${NC}"
  echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

main
