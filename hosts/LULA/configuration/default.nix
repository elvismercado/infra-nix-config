# Manage dotfiles and user packages

{
  pkgs,
  ...
}:

{
  imports = [
    # Host
    ./configuration.nix
    # enable-flakes.nix is not needed — Determinate Nix already enables flakes,
    # and nix.enable = false means nix.settings is not managed by nix-darwin.
    ./user.nix

    # Darwin / UI
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
    ../../../modules/apps/darwin/brave.nix
    ../../../modules/apps/darwin/localsend.nix
  ];

  environment.shells = [ pkgs.bashInteractive ];
  environment.variables.LANG = "en_GB.UTF-8";

  # Homebrew — minimal set for Maria. AppCleaner is the only must-have GUI
  # tool that isn't covered by an Option 3 app façade.
  homebrew = {
    enable = true;
    casks = [
      "appcleaner"
    ];
  };

  # Darwin / UI
  custom.sysDarControlCenter.enable = true;
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
  custom.appBrave.enable = true;
  custom.appBrave.extensions = [ ]; # vanilla Brave for a non-power-user host
  custom.appLocalsend.enable = true;
}
