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

    # Linux
    ../../../modules/home-manager/linux/aliases.nix
    ../../../modules/home-manager/linux/window-shortcuts.nix
    ../../../modules/home-manager/linux/display-profiles.nix

    # Linux / KDE Plasma
    ../../../modules/home-manager/linux/plasma/macos.nix
    ../../../modules/home-manager/linux/sddm-monitor-layout.nix
    ../../../modules/home-manager/linux/kwin-tiling.nix

    # Linux / Gaming
    ../../../modules/home-manager/linux/gaming.nix

    # Linux / Apps
    ../../../modules/home-manager/linux/strawberry.nix
    ../../../modules/home-manager/linux/clonehero.nix

    # Linux / Utilities
    ../../../modules/home-manager/linux/linutil.nix
    ../../../modules/home-manager/linux/autostart.nix
    ../../../modules/home-manager/linux/webcamoid.nix
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

  # AMD CPU diagnostic aliases (FENNEC = Ryzen 9 5900X)
  custom.hmAliasesAmdCpu.enable = true;

  # Apps

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
  custom.hmPlasmaMacos.enable = true;
  custom.hmPlasmaCommon.systray.weather.enable = true;

  # Linux / Gaming
  custom.hmGaming.enable = true;

  # Linux / Apps
  custom.hmStrawberry.enable = true;
  custom.hmCloneHero.enable = true;
  custom.hmCloneHero.hash = "sha256-xy7/3SDNgKw67ikA7CtRVK2gNrfjqx4cTDeRUkkSBKo="; # v1.1.0.6085-final

  # Linux / Utilities
  custom.hmLinutil.enable = true;

  # Autostart — launch tray-friendly apps at login. Window state (start
  # minimized) is enforced by KWin rules in custom.hmPlasmaCommon because
  # the per-app flags below aren't reliably honoured on Wayland. The
  # flags are kept as defense in depth.
  # Note: Syncthing autostarts via its systemd user service (custom.hmSyncthing);
  # Sunshine autostarts via its systemd system service (custom.sysNixSunshine).
  #
  # Coexistence: many apps (Steam, Ferdium, …) install their own
  # ~/.config/autostart/<app>.desktop on first launch. The hmAutostart
  # module compares content at activation: identical files are silently
  # replaced with our symlink; differing files are backed up to
  # <file>.pre-hm.<unix-ts> before we install ours.
  custom.hmAutostart.enable = true;
  custom.hmAutostart.entries = {
    steam = {
      name = "Steam";
      exec = "steam -silent %U";
      icon = "steam";
    };
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
    mullvad-vpn = {
      name = "Mullvad VPN";
      exec = "mullvad-vpn";
      icon = "mullvad-vpn";
    };
    solaar = {
      name = "Solaar";
      exec = "solaar --window=hide";
      icon = "solaar";
    };
  };

  custom.hmWebcamoid.enable = true;
}
