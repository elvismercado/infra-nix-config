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
      # mpv is provided by the home-manager module `custom.hmMpv` (modules/home-manager/all/mpv.nix).
      # Run `brew uninstall mpv` once after the next switch to drop the legacy brew install.
    ];

    casks = [
      # Window management
      "rectangle"

      # Browsers & Communication
      # `brave-browser` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/brave.nix (toggle custom.appBrave.enable).
      # `vesktop` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/discord.nix (toggle custom.appDiscord.enable) —
      # vesktop is preferred over the upstream `discord` cask.
      # `librewolf` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/librewolf.nix (toggle custom.appLibrewolf.enable).
      # Note: `librewolf` cask is deprecated in Homebrew Sep 2026 —
      # revisit before then.
      # `signal` cask is owned by the Option 3 app façade
      # at modules/apps/darwin/signal-desktop.nix (toggle custom.appSignal.enable).

      # Media
      # `handbrake-app` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/handbrake.nix (toggle custom.appHandbrake.enable).
      # `moonlight` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/moonlight.nix (toggle custom.appMoonlight.enable).
      # `shotcut` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/shotcut.nix (toggle custom.appShotcut.enable).
      # `spotify` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/spotify.nix (toggle custom.appSpotify.enable).
      # `steam` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/steam.nix (toggle custom.appSteam.enable).

      # Productivity
      # `beeper` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/beeper.nix (toggle custom.appBeeper.enable).
      # `ferdium` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/ferdium.nix (toggle custom.appFerdium.enable).
      # `nextcloud` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/nextcloud.nix (toggle custom.appNextcloud.enable).
      "orbstack"
      # `syncthing-app` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/syncthing.nix (toggle custom.appSyncthing.enable).

      # Email
      # `thunderbird` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/thunderbird.nix (toggle custom.appThunderbird.enable).

      # Security & VPN
      # `mullvad-vpn` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/mullvad-vpn.nix (toggle custom.appMullvadVpn.enable).
      # `proton-mail-bridge` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/proton-mail-bridge.nix (toggle custom.appProtonmailBridge.enable).

      # Development
      # `visual-studio-code` cask is owned by the Option 3 app façade
      # at modules/apps/darwin/vscode.nix (toggle custom.appVscode.enable).

      # System & Hardware
      "appcleaner"
      # `insync` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/insync.nix (toggle custom.appInsync.enable).
      # `libreoffice`, `localsend`, `raspberry-pi-imager`, and
      # `yubico-authenticator` casks are owned by Option 3 app façades under
      # modules/apps/darwin/ (toggles custom.appLibreoffice.enable,
      # custom.appLocalsend.enable, custom.appRpiImager.enable,
      # custom.appYubicoAuthenticator.enable).
      # `sweet-home3d` cask is owned by the Option 3 app façade at
      # modules/apps/darwin/sweet-home3d.nix (toggle custom.appSweetHome3d.enable).
      "the-unarchiver"
      "unraid-usb-creator-next"
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
