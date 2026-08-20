# Manage dotfiles and user packages

{
  pkgs,
  config,
  ...
}:

{
  imports = [
    # Host
    ./configuration.nix
    # enable-flakes.nix is not needed — Determinate Nix already enables flakes,
    # and nix.enable = false means nix.settings is not managed by nix-darwin.
    ./user.nix
    ./homebrew.nix

    # Darwin / UI
    ../../../modules/systems/darwin/dock.nix
    ../../../modules/systems/darwin/finder.nix
    ../../../modules/systems/darwin/control-center.nix
    ../../../modules/systems/darwin/system-preferences.nix
    ../../../modules/systems/darwin/trackpad.nix

    # Darwin / System
    ../../../modules/systems/darwin/packages.nix
    ../../../modules/systems/darwin/fonts.nix
    ../../../modules/systems/darwin/power.nix
    ../../../modules/systems/darwin/security.nix
    ../../../modules/systems/darwin/time.nix
    ../../../modules/systems/darwin/i18n.nix
    ../../../modules/systems/darwin/tailscale.nix

    # Shared
    ../../../modules/systems/shared/bash.nix

    # Apps (cross-layer façades — see modules/apps/)
    ../../../modules/apps/darwin/vscode.nix
    ../../../modules/apps/darwin/signal-desktop.nix
    ../../../modules/apps/darwin/libreoffice.nix
    ../../../modules/apps/darwin/onlyoffice.nix
    ../../../modules/apps/darwin/rpi-imager.nix
    ../../../modules/apps/darwin/localsend.nix
    ../../../modules/apps/darwin/openlogi.nix
    ../../../modules/apps/darwin/yubico-authenticator.nix
    ../../../modules/apps/darwin/brave.nix
    ../../../modules/apps/darwin/thunderbird.nix
    ../../../modules/apps/darwin/spotify.nix
    ../../../modules/apps/darwin/nextcloud.nix
    ../../../modules/apps/darwin/syncthing.nix
    ../../../modules/apps/darwin/handbrake.nix
    ../../../modules/apps/darwin/mpv.nix
    ../../../modules/apps/darwin/discord.nix
    ../../../modules/apps/darwin/steam.nix
    ../../../modules/apps/darwin/mullvad-vpn.nix
    ../../../modules/apps/darwin/proton-mail-bridge.nix
    ../../../modules/apps/darwin/insync.nix
    ../../../modules/apps/darwin/beeper.nix
    ../../../modules/apps/darwin/ferdium.nix
    ../../../modules/apps/darwin/shotcut.nix
    ../../../modules/apps/darwin/sweet-home3d.nix
    ../../../modules/apps/darwin/moonlight.nix
    ../../../modules/apps/darwin/rustdesk.nix
  ];

  environment.shells = [ pkgs.bashInteractive ];

  # Darwin / UI
  custom.sysDarControlCenter.enable = true;
  custom.sysDarDock.enable = true;
  custom.sysDarFinder.enable = true;
  custom.sysDarPreferences.enable = true;
  custom.sysDarTrackpad.enable = true;

  # Darwin / System
  custom.sysPackages.enable = true;
  custom.sysFonts.enable = true;
  custom.sysDarPower.enable = true;
  custom.sysDarSecurity.enable = true;
  custom.sysDarTimezone.enable = true;
  custom.sysDarI18n.enable = true;
  custom.sysDarTailscale.enable = true;

  # Shared
  custom.sysBashCompletion.enable = true;

  # Apps (cross-layer façades)
  custom.appVscode.enable = true; # cask + HM settings; see modules/apps/darwin/vscode.nix
  custom.appSignal.enable = true;
  custom.appLibreoffice.enable = true;
  custom.appOnlyoffice.enable = true;
  custom.appRpiImager.enable = true;
  custom.appLocalsend.enable = true;
  custom.appOpenLogi.enable = true;
  custom.appYubicoAuthenticator.enable = true;
  custom.appBrave.enable = true;
  custom.appThunderbird.enable = true;
  custom.appSpotify.enable = true;
  custom.appNextcloud.enable = true;
  custom.appSyncthing.enable = true;
  custom.appHandbrake.enable = true;
  custom.appMpv.enable = true;
  custom.appDiscord.enable = true;
  custom.appSteam.enable = true;
  custom.appMullvadVpn.enable = true;
  custom.appProtonmailBridge.enable = true;
  custom.appInsync.enable = true;
  custom.appBeeper.enable = true;
  custom.appFerdium.enable = true;
  custom.appShotcut.enable = true;
  custom.appSweetHome3d.enable = true;
  custom.appMoonlight.enable = true;
  custom.appRustdesk.enable = true;
}
