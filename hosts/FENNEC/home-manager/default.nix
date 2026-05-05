# Manage dotfiles and user packages

{
  ...
}:

let
  # --- FENNEC display profile building blocks ---
  # M1: dual-mode primary on DP-3 (4K @ 160Hz scale 1.7  /  1080p @ 320Hz scale 1.0)
  # M2: portrait on DP-2 (1920x1200 @ 100Hz, rotated right)
  # M3: 4K landscape on HDMI-A-1 (3840x2160 @ 60Hz)
  # Layout when all present: M1 (primary) → M2 (right of M1) → M3 (right of M2)
  # M1 wired to DP-3 so NVIDIA POSTs BIOS/GRUB/SDDM on M1 (highest-numbered DP wins).

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

  # M2 next to M1 (right-of-DP-3)
  m2WithM1 = {
    resolution = "1920x1200";
    scale = 1.0;
    refreshRate = 100;
    orientation = "right";
    brightness = 1.0;
    position = "right-of-DP-3";
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

  # M3 right of M2 (full chain)
  m3RightOfM2 = {
    resolution = "3840x2160";
    scale = 1.7;
    refreshRate = 60;
    orientation = "normal";
    brightness = 1.0;
    position = "right-of-DP-2";
  };

  # M3 right of M1 (when M2 absent)
  m3RightOfM1 = {
    resolution = "3840x2160";
    scale = 1.7;
    refreshRate = 60;
    orientation = "normal";
    brightness = 1.0;
    position = "right-of-DP-3";
  };

  # M3 standalone (no anchor, becomes primary)
  m3Alone = {
    resolution = "3840x2160";
    scale = 1.7;
    refreshRate = 60;
    orientation = "normal";
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
    ../../../modules/home-manager/linux/sddm-monitor-layout.nix

    # Linux / Gaming
    ../../../modules/home-manager/linux/gaming.nix

    # Linux / Apps
    ../../../modules/home-manager/linux/handbrake.nix
    ../../../modules/home-manager/linux/strawberry.nix
    ../../../modules/home-manager/linux/vesktop.nix

    # Linux / Utilities
    ../../../modules/home-manager/linux/linutil.nix
    ../../../modules/home-manager/linux/autostart.nix

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
  custom.hmDisplayProfiles.enable = true;
  custom.hmSddmMonitorLayout.enable = true;
  custom.hmSddmMonitorLayout.profile = "m1-4k+all";
  custom.hmSddmMonitorLayout.disabledOutputs = [
    "DP-2"
    "HDMI-A-1"
  ]; # login screen on M1 only

  # Display profiles — 7 topologies × M1's 2 hardware modes = 11 profiles.
  # Match uses max resolution from DRM sysfs, so M1's hardware mode toggle
  # picks between m1-4k* and m1-hd* automatically.
  custom.hmDisplayProfiles.profiles = {

    # --- M1 only ---
    "m1-4k" = {
      match."DP-3" = "3840x2160";
      outputs."DP-3" = m1At4k;
    };
    "m1-hd" = {
      match."DP-3" = "1920x1080";
      outputs."DP-3" = m1AtHd;
    };

    # --- M2 only ---
    "m2" = {
      match."DP-2" = "1920x1200";
      outputs."DP-2" = m2Alone;
    };

    # --- M3 only ---
    "m3" = {
      match."HDMI-A-1" = "4096x2160";
      outputs."HDMI-A-1" = m3Alone;
    };

    # --- M2 + M3 (no M1) ---
    "m2+m3" = {
      match."DP-2" = "1920x1200";
      match."HDMI-A-1" = "4096x2160";
      outputs."DP-2" = m2Alone;
      outputs."HDMI-A-1" = m3RightOfM2;
    };

    # --- M1 + M2 ---
    "m1-4k+m2" = {
      match."DP-3" = "3840x2160";
      match."DP-2" = "1920x1200";
      outputs."DP-3" = m1At4k;
      outputs."DP-2" = m2WithM1;
    };
    "m1-hd+m2" = {
      match."DP-3" = "1920x1080";
      match."DP-2" = "1920x1200";
      outputs."DP-3" = m1AtHd;
      outputs."DP-2" = m2WithM1;
    };

    # --- M1 + M3 (M2 absent — M3 sits where M2 normally would) ---
    "m1-4k+m3" = {
      match."DP-3" = "3840x2160";
      match."HDMI-A-1" = "4096x2160";
      outputs."DP-3" = m1At4k;
      outputs."HDMI-A-1" = m3RightOfM1;
    };
    "m1-hd+m3" = {
      match."DP-3" = "1920x1080";
      match."HDMI-A-1" = "4096x2160";
      outputs."DP-3" = m1AtHd;
      outputs."HDMI-A-1" = m3RightOfM1;
    };

    # --- M1 + M2 + M3 (full chain) ---
    "m1-4k+all" = {
      match."DP-3" = "3840x2160";
      match."DP-2" = "1920x1200";
      match."HDMI-A-1" = "4096x2160";
      outputs."DP-3" = m1At4k;
      outputs."DP-2" = m2WithM1;
      outputs."HDMI-A-1" = m3RightOfM2;
    };
    "m1-hd+all" = {
      match."DP-3" = "1920x1080";
      match."DP-2" = "1920x1200";
      match."HDMI-A-1" = "4096x2160";
      outputs."DP-3" = m1AtHd;
      outputs."DP-2" = m2WithM1;
      outputs."HDMI-A-1" = m3RightOfM2;
    };
  };

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

  # Autostart — launch tray-friendly apps at login. Window state (start
  # minimized) is enforced by KWin rules in custom.hmPlasmaConfig because
  # the per-app flags below aren't reliably honoured on Wayland. The
  # flags are kept as defense in depth.
  # Note: Syncthing autostarts via its systemd user service (custom.hmSyncthing);
  # Sunshine autostarts via its systemd system service (custom.sysNixSunshine).
  #
  # Before adding an entry: many apps (Steam, Discord clients, …) install
  # their own ~/.config/autostart/<app>.desktop on first launch — declaring
  # them here would collide with home-manager's symlink activation ("file
  # already exists" errors). Run `ls ~/.config/autostart/ /etc/xdg/autostart/`
  # first; if a stale plain file exists for an app declared below, remove
  # it before rebuild. Steam is intentionally omitted — its own autostart
  # entry is left in place.
  custom.hmAutostart.enable = true;
  custom.hmAutostart.entries = {
    vesktop = {
      name = "Vesktop";
      exec = "vesktop --start-minimized";
      icon = "vesktop";
    };
    beeper = {
      name = "Beeper";
      exec = "beeper --hidden";
      icon = "beeper";
    };
    ferdium = {
      name = "Ferdium";
      exec = "ferdium --hidden";
      icon = "ferdium";
    };
    solaar = {
      name = "Solaar";
      exec = "solaar --window=hide";
      icon = "solaar";
    };
  };

  # Packages
  custom.hmLinuxPackages.enable = true;
}
