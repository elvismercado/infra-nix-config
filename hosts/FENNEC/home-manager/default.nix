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

    # Apps
    ../../../modules/home-manager/all/brave.nix
    ../../../modules/home-manager/all/mpv.nix
    ../../../modules/home-manager/linux/vscode.nix
    ../../../modules/home-manager/all/syncthing.nix

    # Linux
    ../../../modules/home-manager/linux/aliases.nix
    ../../../modules/home-manager/linux/window-shortcuts.nix
    ../../../modules/home-manager/linux/display-profiles.nix

    # Linux / KDE Plasma
    ../../../modules/home-manager/linux/plasma-config.nix

    # Linux / Gaming
    ../../../modules/home-manager/linux/gaming.nix

    # Linux / Apps
    ../../../modules/home-manager/linux/handbrake.nix
    ../../../modules/home-manager/linux/strawberry.nix
    ../../../modules/home-manager/linux/vesktop.nix

    # Linux / Utilities
    ../../../modules/home-manager/linux/linutil.nix

    # Packages
    ../../../modules/home-manager/linux/packages.nix
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

  # Apps
  custom.hmBrave.enable = true;
  custom.hmMpv.enable = true;
  custom.hmVscode.enable = true;
  custom.hmSyncthing.enable = true;

  # Linux
  custom.hmLinuxAliases.enable = true;
  custom.hmWindowShortcuts.enable = true;
  # disabled — no profiles defined yet (see TODO.md Backlog)
  # custom.hmDisplayProfiles.enable = true;

  # Linux / KDE Plasma
  custom.hmPlasmaConfig.enable = true;

  # Linux / Gaming
  custom.hmGaming.enable = true;

  # Linux / Apps
  custom.hmHandbrake.enable = true;
  custom.hmStrawberry.enable = true;
  custom.hmVesktop.enable = true;

  # Linux / Utilities
  custom.hmLinutil.enable = true;

  # Packages
  custom.hmLinuxPackages.enable = true;
}
