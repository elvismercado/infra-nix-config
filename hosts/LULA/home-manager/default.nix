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
    ../../../modules/home-manager/linux/plasma-config.nix
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

  # Linux / KDE Plasma — minimal layout, weather widget enabled
  # (uses userSettings.weatherLocation from the private overlay).
  custom.hmPlasmaConfig.enable = true;
  custom.hmPlasmaConfig.layout = "minimal";
  custom.hmPlasmaConfig.systray.weather.enable = true;
}
