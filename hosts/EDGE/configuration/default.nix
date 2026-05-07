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

    # Shared
    ../../../modules/systems/shared/bash.nix

    # Apps (cross-layer façades — see modules/apps/)
    ../../../modules/apps/darwin/vscode.nix
    ../../../modules/apps/darwin/signal-desktop.nix
    ../../../modules/apps/darwin/libreoffice.nix
    ../../../modules/apps/darwin/rpi-imager.nix
    ../../../modules/apps/darwin/localsend.nix
    ../../../modules/apps/darwin/yubico-authenticator.nix
  ];

  environment.shells = [ pkgs.bashInteractive ];
  environment.variables.LANG = "en_GB.UTF-8";

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

  # Shared
  custom.sysBashCompletion.enable = true;

  # Apps (cross-layer façades)
  custom.appVscode.enable = true; # cask + HM settings; see modules/apps/darwin/vscode.nix
  custom.appSignal.enable = true;
  custom.appLibreoffice.enable = true;
  custom.appRpiImager.enable = true;
  custom.appLocalsend.enable = true;
  custom.appYubicoAuthenticator.enable = true;
}
