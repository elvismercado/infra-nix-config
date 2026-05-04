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
    ../../../modules/home-manager/all/ansible.nix
    ../../../modules/home-manager/all/bash.nix
    ../../../modules/home-manager/all/fastfetch.nix
    ../../../modules/home-manager/all/fnm.nix
    ../../../modules/home-manager/all/git.nix
    ../../../modules/home-manager/all/pyenv.nix
    ../../../modules/home-manager/all/ssh.nix
    ../../../modules/home-manager/all/starship.nix

    # Apps
    ../../../modules/home-manager/all/android.nix
    ../../../modules/home-manager/all/brave.nix
    ../../../modules/home-manager/all/mpv.nix
    ../../../modules/home-manager/all/thunderbird.nix
    ../../../modules/home-manager/linux/vscode.nix

    # Linux
    ../../../modules/home-manager/linux/aliases.nix

    # Linux / KDE Plasma
    ../../../modules/home-manager/linux/plasma-config.nix
    ../../../modules/home-manager/linux/window-shortcuts.nix
    ../../../modules/home-manager/linux/display-profiles.nix
    ../../../modules/home-manager/linux/shutdown-disable-outputs.nix

    # Linux / Utilities
    ../../../modules/home-manager/linux/linutil.nix

    # Services
    ../../../modules/home-manager/linux/nextcloud.nix
    ../../../modules/home-manager/all/syncthing.nix

    # Packages
    ../../../modules/home-manager/linux/packages.nix
  ];

  # Host
  # (host-specific config in home.nix)

  # Base
  custom.hmBase.enable = true;

  # Shell
  custom.hmAliases.enable = true;
  custom.hmAliasesAmdCpu.enable = true;
  custom.hmAnsible.enable = true;
  custom.hmBash.enable = true;
  custom.hmFastfetch.enable = true;
  custom.hmFnm.enable = true;
  custom.hmGit.enable = true;
  custom.hmPyenv.enable = true;
  custom.hmSsh.enable = true;
  custom.hmStarship.enable = true;
  custom.hmStarship.style = "pastel-powerline";

  # Linux
  custom.hmLinuxAliases.enable = true;

  # Linux / Utilities
  custom.hmLinutil.enable = true;

  # Apps
  custom.hmAndroid.enable = true;
  custom.hmBrave.enable = true;
  custom.hmMpv.enable = true;
  custom.hmPlasmaConfig.enable = true;
  custom.hmWindowShortcuts.enable = true;
  custom.hmThunderbird.enable = true;
  custom.hmVscode.enable = true;

  # Services
  custom.hmDisplayProfiles.enable = true;
  # parked — see TODO.md Backlog (decide: remove or upgrade)
  # custom.hmShutdownDisableOutputs.enable = true;
  # custom.hmShutdownDisableOutputs.connectors = [ "DP-2" ]; # disable DP-2 before shutdown for clean Plymouth splash

  # Dual-monitor profiles (DP-2 connected — score 2, wins over single)
  custom.hmDisplayProfiles.profiles."4k-dual" = {
    match."DP-1" = "3840x2160";
    match."DP-2" = "1920x1200";
    outputs."DP-1" = {
      resolution = "3840x2160";
      scale = 1.5;
      refreshRate = 60;
      orientation = "normal";
      brightness = 1.0;
    };
    outputs."DP-2" = {
      resolution = "1920x1200";
      scale = 1.0;
      refreshRate = 100;
      orientation = "right";
      brightness = 1.0;
      position = "right-of-DP-1";
    };
  };
  custom.hmDisplayProfiles.profiles."2k-dual" = {
    match."DP-1" = "2560x1440";
    match."DP-2" = "1920x1200";
    outputs."DP-1" = {
      resolution = "2560x1440";
      scale = 1.0;
      refreshRate = 100;
      orientation = "normal";
      brightness = 1.0;
    };
    outputs."DP-2" = {
      resolution = "1920x1200";
      scale = 1.0;
      refreshRate = 100;
      orientation = "right";
      brightness = 1.0;
      position = "right-of-DP-1";
    };
  };
  custom.hmDisplayProfiles.profiles."1080p-dual" = {
    match."DP-1" = "1920x1080";
    match."DP-2" = "1920x1200";
    outputs."DP-1" = {
      resolution = "1920x1080";
      scale = 1.0;
      refreshRate = 100;
      orientation = "normal";
      brightness = 1.0;
    };
    outputs."DP-2" = {
      resolution = "1920x1200";
      scale = 1.0;
      refreshRate = 100;
      orientation = "right";
      brightness = 1.0;
      position = "right-of-DP-1";
    };
  };

  # Single-monitor profiles (DP-2 disconnected — score 1, fallback)
  custom.hmDisplayProfiles.profiles."4k-single" = {
    match."DP-1" = "3840x2160";
    outputs."DP-1" = {
      resolution = "3840x2160";
      scale = 1.5;
      refreshRate = 60;
      orientation = "normal";
      brightness = 1.0;
    };
  };
  custom.hmDisplayProfiles.profiles."2k-single" = {
    match."DP-1" = "2560x1440";
    outputs."DP-1" = {
      resolution = "2560x1440";
      scale = 1.0;
      refreshRate = 100;
      orientation = "normal";
      brightness = 1.0;
    };
  };
  custom.hmDisplayProfiles.profiles."1080p-single" = {
    match."DP-1" = "1920x1080";
    outputs."DP-1" = {
      resolution = "1920x1080";
      scale = 1.0;
      refreshRate = 100;
      orientation = "normal";
      brightness = 1.0;
    };
  };

  custom.hmNextcloud.enable = true;
  custom.hmSyncthing.enable = true;

  # Packages
  custom.hmLinuxPackages.enable = true;
}
