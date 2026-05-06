# Manage dotfiles and user packages

{
  ...
}:

let
  # --- JIN display profile building blocks ---
  # M1: dual-mode primary on DP-1 (4K @ 160Hz scale 1.7  /  1080p @ 320Hz scale 1.0)
  # M2: portrait on DP-2 (1920x1200 @ 100Hz, rotated right)
  # Layout when both present: M1 (primary) → M2 (right of M1)

  m1At4k = {
    resolution = "3840x2160";
    scale = 1.7;
    refreshRate = 160;
    orientation = "normal";
    brightness = 1.0;
    primary = true;
  };

  m1AtHd = {
    resolution = "1920x1080";
    scale = 1.0;
    refreshRate = 320;
    orientation = "normal";
    brightness = 1.0;
    primary = true;
  };

  # M2 next to M1 (right-of-DP-1)
  m2WithM1 = {
    resolution = "1920x1200";
    scale = 1.0;
    refreshRate = 100;
    orientation = "right";
    brightness = 1.0;
    position = "right-of-DP-1";
  };

  # M2 standalone (no anchor, becomes primary)
  m2Alone = {
    resolution = "1920x1200";
    scale = 1.0;
    refreshRate = 100;
    orientation = "right";
    brightness = 1.0;
    primary = true;
  };
in

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
    ../../../modules/home-manager/linux/sddm-monitor-layout.nix
    ../../../modules/home-manager/linux/shutdown-disable-outputs.nix
    ../../../modules/home-manager/linux/kwin-tiling.nix

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
  custom.hmSddmMonitorLayout.enable = true;
  custom.hmSddmMonitorLayout.profile = "m1-4k+m2";
  custom.hmSddmMonitorLayout.disabledOutputs = [ "DP-2" ]; # login screen on M1 only
  # parked — see TODO.md Backlog (decide: remove or upgrade)
  # custom.hmShutdownDisableOutputs.enable = true;
  # custom.hmShutdownDisableOutputs.connectors = [ "DP-2" ]; # disable DP-2 before shutdown for clean Plymouth splash

  # KWin custom tile layouts — portrait M2 split into 3 stacked rows.
  # UUID is auto-resolved from the connector at activation time.
  # KWin requires the root to be horizontal; the vertical 3-row tree is
  # wrapped in a single horizontal child with width = 1.
  custom.hmKwinTiling.enable = true;
  custom.hmKwinTiling.layouts.m2 = {
    connector = "DP-2";
    tiles = {
      layoutDirection = "horizontal";
      tiles = [
        {
          layoutDirection = "vertical";
          width = 1;
          tiles = [
            { height = 0.333; }
            { height = 0.333; }
            { height = 0.334; }
          ];
        }
      ];
    };
  };

  # Display profiles — 5 topologies covering M1's 2 hardware modes × M2 presence.
  # Match uses max resolution from DRM sysfs, so M1's hardware mode toggle
  # picks between m1-4k* and m1-hd* automatically.
  custom.hmDisplayProfiles.profiles = {

    # --- M1 only ---
    "m1-4k" = {
      match."DP-1" = "3840x2160";
      outputs."DP-1" = m1At4k;
    };
    "m1-hd" = {
      match."DP-1" = "1920x1080";
      outputs."DP-1" = m1AtHd;
    };

    # --- M2 only ---
    "m2" = {
      match."DP-2" = "1920x1200";
      outputs."DP-2" = m2Alone;
    };

    # --- M1 + M2 ---
    "m1-4k+m2" = {
      match."DP-1" = "3840x2160";
      match."DP-2" = "1920x1200";
      outputs."DP-1" = m1At4k;
      outputs."DP-2" = m2WithM1;
    };
    "m1-hd+m2" = {
      match."DP-1" = "1920x1080";
      match."DP-2" = "1920x1200";
      outputs."DP-1" = m1AtHd;
      outputs."DP-2" = m2WithM1;
    };
  };

  custom.hmNextcloud.enable = true;
  custom.hmSyncthing.enable = true;

  # Packages
  custom.hmLinuxPackages.enable = true;
}
