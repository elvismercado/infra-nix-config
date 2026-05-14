# Manage dotfiles and user packages

{
  ...
}:

{
  imports = [
    # Host
    ./home.nix

    # Base
    ../../../modules/home-manager/all/base.nix

    # Shell
    ../../../modules/home-manager/all/aliases.nix
    ../../../modules/home-manager/all/bash.nix
    ../../../modules/home-manager/all/fastfetch.nix
    ../../../modules/home-manager/all/git.nix
    ../../../modules/home-manager/all/ssh.nix
    ../../../modules/home-manager/all/starship.nix

    # Linux
    ../../../modules/home-manager/linux/aliases.nix
    ../../../modules/home-manager/linux/plasma/lula.nix
  ];

  # Base
  custom.hmBase.enable = true;

  # Shell
  custom.hmAliases.enable = true;
  custom.hmBash.enable = true;
  custom.hmFastfetch.enable = true;
  custom.hmGit.enable = true;
  custom.hmSsh.enable = true;
  custom.hmStarship.enable = true;
  custom.hmStarship.style = "pastel-powerline";

  # Linux
  custom.hmLinuxAliases.enable = true;

  # Linux / KDE Plasma — LULA layout (top tray panel + bottom dock,
  # no Global Menu). Weather widget pulls from the private overlay's
  # userSettings.weatherLocation. Hot corners disabled to avoid
  # accidental Overview triggers.
  custom.hmPlasmaLula.enable = true;
  custom.hmPlasmaCommon.systray.weather.enable = true;
  custom.hmPlasmaCommon.hotCorners.enable = false;
  custom.hmPlasmaCommon.kwallet.enable = false;
}
