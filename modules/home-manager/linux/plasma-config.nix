# Plasma Desktop Configuration — macOS-style panel layout
# https://github.com/nix-community/plasma-manager
#
# Configures a macOS-inspired two-panel layout:
#   - Top panel: menu bar with Global Menu, System Tray, and Digital Clock
#   - Bottom panel: floating dock with Icons-only Task Manager
#
# Also sets:
#   - Window buttons on the right (standard convention)
#   - KRunner centered (Spotlight-style)
#   - Single-click to open files/folders
#   - No splash screen (Plymouth handles the boot splash)
#   - Login starts with empty session (no app restore)
#   - New windows open under the cursor (UnderMouse placement)
#   - Desktop icons arranged top-to-bottom, left-aligned
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/plasma-config.nix ];
#   custom.hmPlasmaConfig.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

{
  options = {
    custom.hmPlasmaConfig.enable = lib.mkEnableOption "macOS-style KDE Plasma layout (top menu bar, floating dock, centered KRunner)";
  };

  config = lib.mkIf config.custom.hmPlasmaConfig.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmPlasmaConfig requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
    ];
    # Webcam app (Qt, replaces Kamoso)
    home.packages = [
      pkgs.webcamoid
    ];

    programs.plasma = {
      enable = true;

      # ── Panels ──────────────────────────────────────────────────────
      panels = [
        # Top panel — menu bar
        # No `screen` set: plasma-manager only pins by numeric index, but DRM
        # enumerates connectors in an unstable order on FENNEC (NVIDIA + 3
        # outputs + KVM) so the index for M1 changes between boots. Letting
        # Plasmashell place the panel on the KScreen-tracked primary output
        # (M1 via `primary = true` in the host display profile) is the only
        # stable option.
        {
          location = "top";
          height = 28;
          lengthMode = "fill";
          floating = false;
          widgets = [
            # App launcher — uncomment ONE of the following:
            # "org.kde.plasma.kickoff"        # Kickoff: traditional start menu
            # "org.kde.plasma.kicker" # Application Menu: compact cascading menu
            "org.kde.plasma.kickerdash" # Application Dashboard: full-screen grid (Launchpad-style)

            # Global Menu — shows the focused window's menu bar
            "org.kde.plasma.appmenu"

            # Flexible spacer pushes the rest to the right
            "org.kde.plasma.panelspacer"

            # System Tray — network, volume, notifications, etc.
            {
              systemTray = {
                icons.scaleToFit = true;
                items = {
                  shown = [
                    "org.kde.plasma.bluetooth"
                    "org.kde.plasma.cameraindicator"
                    "org.kde.plasma.lock_keys"
                  ];
                };
              };
            }

            # Clock
            {
              digitalClock = {
                calendar.firstDayOfWeek = "monday";
                time.format = "24h";
              };
            }

            # Peek at / show desktop
            "org.kde.plasma.showdesktop"
          ];
        }

        # Bottom panel — floating app dock
        {
          location = "bottom";
          height = 56;
          floating = true;
          alignment = "center";
          lengthMode = "fit";
          hiding = "dodgewindows"; # slides away when a window touches it
          widgets = [
            {
              iconTasks = {
                launchers = [
                  "applications:systemsettings.desktop"
                  "applications:org.kde.dolphin.desktop"
                  "preferred://browser"
                ];
              };
            }
          ];
        }
      ];

      # ── Window Management ───────────────────────────────────────────
      kwin = {
        tiling.padding = 4; # 4px gap between tiled windows

        titlebarButtons = {
          left = [ ];
          right = [
            "minimize"
            "maximize"
            "close"
          ];
        };
      };

      # ── KRunner ─────────────────────────────────────────────────────
      krunner = {
        position = "center"; # centered like Spotlight
        historyBehavior = "enableSuggestions";
      };

      # ── Workspace ───────────────────────────────────────────────────
      workspace = {
        clickItemTo = "open"; # single-click to open (macOS default)
        splashScreen.theme = "None"; # Plymouth handles boot splash
      };

      # ── Desktop icons ────────────────────────────────────────────────
      # Re-anchor icons against the available geometry (excludes panel
      # struts) so they line up below the top panel instead of under it.
      desktop.icons = {
        arrangement = "topToBottom";
        alignment = "left";
        lockInPlace = false;
      };

      # ── Session ──────────────────────────────────────────────────────
      # Login starts with no apps reopened — no remembered window/screen
      # state from the previous session.
      session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

      # ── KWin window placement ────────────────────────────────────────
      # New windows open at the cursor position so they appear on whichever
      # monitor you're currently working on. Note: apps that explicitly
      # request a position (Brave, VS Code with "continue where you left
      # off") still apply their own saved geometry — that's a per-app
      # setting, not KWin's call.
      configFile."kwinrc"."Windows".Placement = "UnderMouse";    };
  };
}
