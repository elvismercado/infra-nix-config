#!/bin/bash
set -e

# Bootstrap script for cloning + initial build of the nix-config flake.
#
# Required sibling: `elvismercado/nix-config-private` (private repo with
# PII-bearing per-host fields and the Syncthing peer mesh). The flake
# declares it as a `flake = false` input (`url = "git+file:../nix-config-private"`)
# — without it on disk next to this repo, `darwin-rebuild` and
# `nixos-rebuild` fail at flake eval with `cannot read input 'private'`.
#
# This script offers to clone the sibling interactively after the public
# repo is in place. If you decline, you'll need to provide the sibling
# yourself (or run install.sh's stub fallback) before the first rebuild.

REPO_NAME="nix-config"
REPO_DIR="$HOME/git/$REPO_NAME"
PRIVATE_REPO_NAME="nix-config-private"
PRIVATE_REPO_DIR="$HOME/git/$PRIVATE_REPO_NAME"

fatal() {
  echo "[Setup] ERROR: $*" >&2
  exit 1
}

get_os_name() {
  [ -f /etc/os-release ] || return 1
  awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release
}

get_os_type() {
  OS_TYPE=$(uname)

  if [ "$OS_TYPE" = "Linux" ]; then
    echo "[Setup] Linux detected"
    OS_NAME=$(get_os_name)
    echo "[Setup] OS is $OS_NAME"

    if grep -qi NixOS /etc/os-release 2>/dev/null; then
      echo "[Setup nixos] NixOS detected"
      echo "[Setup nixos] Add the following to '/etc/nixos/configuration.nix'"
      echo "[Setup nixos] 'nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];'"
      echo "[Setup nixos] run 'sudo nixos-rebuild switch' after"
    fi
  elif [ "$OS_TYPE" = "Darwin" ]; then
    echo "[Setup] Darwin detected"
  else
    echo "[Setup] Not on Linux or Darwin"
  fi
}

is_nix_installed() {
  command -v nix >/dev/null 2>&1
}

source_nix() {
  # Source Nix profile so nix/nix-shell are available in this session
  if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  fi
}

run_determinite_installer() {
  # Determinate Nix Installer (with flakes enabled by default)
  #
  # Why? Because it will install Nix package manager allowing us to use packages
  # without installing them and help with the rest of the setup
  #
  # https://github.com/DeterminateSystems/nix-installer?tab=readme-ov-file#installation
  #
  # `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate`

  if is_nix_installed; then
    echo "[Setup] Nix already installed, skipping installer"
    return 0
  fi

  echo "[Setup] Running the Determinate installer"

  # Download installer to a temp file and verify before executing.
  # Avoids the silent-failure trap of `curl | sh` (where a failed curl can
  # still leave the pipeline exit status as 0, or pipe a partial script to sh).
  installer=$(mktemp -t determinate-nix-installer.XXXXXX) \
    || fatal "Failed to create temp file for installer."
  trap 'rm -f "$installer"' EXIT

  curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix -o "$installer" \
    || fatal "Failed to download Determinate Nix installer."

  [ -s "$installer" ] || fatal "Downloaded Determinate Nix installer is empty."

  sh "$installer" install --determinate

  rm -f "$installer"
  trap - EXIT

  # Make nix available in this shell session
  source_nix
}

install_xcode_clt() {
  # Xcode Command Line Tools (required for git, compilers, Homebrew, pyenv, etc.)
  # Only needed on macOS — skips if already installed.

  if [ "$(uname)" != "Darwin" ]; then
    return 0
  fi

  if /usr/bin/xcode-select -p >/dev/null 2>&1; then
    echo "[Setup] Xcode Command Line Tools already installed, skipping"
    return 0
  fi

  echo "[Setup] Installing Xcode Command Line Tools..."
  /usr/bin/xcode-select --install

  # Wait for installation to complete (the installer runs in the background)
  echo "[Setup] Waiting for Xcode CLT installation to complete..."
  local max_attempts=180 # 15 minutes (180 × 5s)
  local attempt=0
  until /usr/bin/xcode-select -p >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
      fatal "Timed out waiting for Xcode CLT installation (15 minutes). Install manually with: xcode-select --install"
    fi
    sleep 5
  done
  echo "[Setup] Xcode Command Line Tools installed"
}

install_homebrew() {
  # Homebrew package manager (required for nix-darwin's homebrew module)
  # Only needed on macOS — skips if already installed.
  # https://brew.sh

  if [ "$(uname)" != "Darwin" ]; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "[Setup] Homebrew already installed, skipping"
    return 0
  fi

  echo "[Setup] Installing Homebrew..."

  # Download installer to a temp file and verify before executing.
  # Avoids silent failure when `curl` returns an empty/partial script.
  installer=$(mktemp -t homebrew-installer.XXXXXX) \
    || fatal "Failed to create temp file for installer."
  trap 'rm -f "$installer"' EXIT

  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer" \
    || fatal "Failed to download Homebrew installer."

  [ -s "$installer" ] || fatal "Downloaded Homebrew installer is empty."

  /bin/bash "$installer"

  rm -f "$installer"
  trap - EXIT

  # Add Homebrew to PATH for this session
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  echo "[Setup] Homebrew installed"
}

download_repo() {
  local repo_url="https://github.com/elvismercado/nix-config.git"
  mkdir -p ~/git

  if [ -d "$REPO_DIR" ]; then
    echo "[Setup] Repo already exists at $REPO_DIR"
    printf "[Setup] Delete and fresh clone? [y/N] "
    read -r answer
    case "$answer" in
      [yY]*)
        echo "[Setup] Removing $REPO_DIR..."
        rm -rf "$REPO_DIR"
        ;;
      *)
        echo "[Setup] Keeping existing repo, skipping clone"
        return 0
        ;;
    esac
  fi

  echo "[Setup] Cloning repo to $REPO_DIR..."
  nix-shell -p git --run "git clone '$repo_url' '$REPO_DIR'" \
    || fatal "Failed to clone $repo_url. Check your network connection."

  echo "[Setup] Ready to use nix-config"
}

clone_private_sibling() {
  # The flake declares `inputs.private = git+file:../nix-config-private` as
  # a required input. Without the sibling, every rebuild fails at flake eval.
  # This step is interactive — the user may decline and provide the sibling
  # themselves (e.g. via install.sh's stub fallback on NixOS, or a manual
  # clone later).

  if [ -d "$PRIVATE_REPO_DIR" ]; then
    echo "[Setup] Private sibling already present at $PRIVATE_REPO_DIR, skipping"
    return 0
  fi

  echo ""
  echo "[Setup] The flake requires a sibling repo 'nix-config-private' next to nix-config."
  echo "[Setup] Without it, darwin-rebuild / nixos-rebuild fail at flake eval."
  printf "[Setup] Clone elvismercado/nix-config-private into $PRIVATE_REPO_DIR now? [y/N] "
  read -r answer
  case "$answer" in
    [yY]*)
      ;;
    *)
      echo "[Setup] Skipped. Provide the sibling before your first rebuild:"
      echo "[Setup]   gh repo clone elvismercado/nix-config-private $PRIVATE_REPO_DIR"
      echo "[Setup] See nix-config/README.md ‘PII & Secrets Discipline’ for details."
      return 0
      ;;
  esac

  # Tier order: pre-authenticated gh → interactive gh auth → SSH → HTTPS.
  # The interactive gh tier covers the common case of "gh installed but
  # never used" — a quick web/device-code login bootstraps the clone
  # without forcing the user to drop out, run gh manually, and resume.
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "[Setup] Cloning private sibling via gh (already authenticated)..."
    if gh repo clone elvismercado/nix-config-private "$PRIVATE_REPO_DIR"; then
      echo "[Setup] Private sibling cloned to $PRIVATE_REPO_DIR"
      return 0
    fi
    echo "[Setup] gh clone failed, falling back to SSH..."
  elif command -v gh >/dev/null 2>&1; then
    echo "[Setup] gh installed but not authenticated."
    printf "[Setup] Authenticate with GitHub now (web/device-code flow)? [y/N] "
    read -r auth_answer
    case "$auth_answer" in
      [yY]*)
        if gh auth login -h github.com -p https -w; then
          if gh repo clone elvismercado/nix-config-private "$PRIVATE_REPO_DIR"; then
            echo "[Setup] Private sibling cloned to $PRIVATE_REPO_DIR"
            return 0
          fi
          echo "[Setup] gh clone failed after auth, falling back to SSH..."
        else
          echo "[Setup] gh auth login failed/cancelled, falling back to SSH..."
        fi
        ;;
      *)
        echo "[Setup] Skipped gh auth, falling back to SSH..."
        ;;
    esac
  fi

  if nix-shell -p git --run "git clone git@github.com:elvismercado/nix-config-private.git '$PRIVATE_REPO_DIR'" 2>/dev/null; then
    echo "[Setup] Private sibling cloned via SSH to $PRIVATE_REPO_DIR"
    return 0
  fi

  echo "[Setup] SSH clone failed, trying HTTPS..."
  if nix-shell -p git --run "git clone https://github.com/elvismercado/nix-config-private.git '$PRIVATE_REPO_DIR'" 2>/dev/null; then
    echo "[Setup] Private sibling cloned via HTTPS to $PRIVATE_REPO_DIR"
    return 0
  fi

  echo "[Setup] All clone methods failed. The sibling is still needed."
  echo "[Setup] After authenticating GitHub, run:"
  echo "[Setup]   gh repo clone elvismercado/nix-config-private $PRIVATE_REPO_DIR"
  echo "[Setup] Continuing without it — rebuilds will fail until it's in place."
}

# Start
echo "[Setup] Starting script..."

get_os_type

# Install this first! (if not on NixOS)
run_determinite_installer

# Ensure nix is available (may already be installed from a previous run)
source_nix

# macOS prerequisites (idempotent — skipped on Linux)
install_xcode_clt
install_homebrew

download_repo
clone_private_sibling
