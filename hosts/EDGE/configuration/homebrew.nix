# Homebrew packages for EDGE
#
# Bootstrap: scripts/setup.sh installs the Homebrew binary itself; this module
# only declares which formulae / casks / Mac App Store apps nix-darwin should
# manage on activation.
#
# Categories below are the source of truth — hosts/EDGE/README.md just points
# here, so there's no list to keep in sync.
#
# Conventions (see .github/copilot-instructions.md "Package Install Priority"):
#   - GUI apps go in `casks` (gives Spotlight, Gatekeeper, auto-update).
#     Never pair a cask with a nixpkgs package for the same app.
#   - `brews` is reserved for CLI tools that have no cask equivalent.
#   - `masApps` is the Mac App Store — only when an app is App Store-exclusive
#     (e.g. WireGuard's official macOS distribution channel).
#   - Verify cask names at https://formulae.brew.sh before adding/renaming;
#     casks get renamed periodically (see .github/instructions/nix-darwin.instructions.md).

{ ... }:

{
  homebrew = {
    enable = true;

    # CLI/GUI tools without a cask equivalent
    brews = [
      "mpv" # CLI/GUI media player
    ];

    casks = [
      # Window management
      "rectangle"

      # Browsers & Communication
      "brave-browser"
      "discord"
      "librewolf" # deprecated in Homebrew Sep 2026 — revisit before then
      "signal"

      # Media
      "handbrake-app"
      "moonlight"
      "shotcut"
      "spotify"
      "steam"
      "vlc"

      # Productivity
      "beeper"
      "ferdium"
      "nextcloud"
      "orbstack"
      "syncthing-app"

      # Email
      "thunderbird"

      # Security & VPN
      "mullvad-vpn"
      "proton-mail-bridge"

      # Development
      "visual-studio-code"

      # System & Hardware
      "appcleaner"
      "insync"
      "libreoffice"
      "localsend"
      "raspberry-pi-imager"
      "sweet-home3d"
      "the-unarchiver"
      "unraid-usb-creator-next"
      "yubico-authenticator"
    ];

    # Mac App Store apps — App Store-only distribution
    masApps = {
      "WireGuard" = 1451685025;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # cleanup = "uninstall"; # remove packages not in config
    };
  };
}
