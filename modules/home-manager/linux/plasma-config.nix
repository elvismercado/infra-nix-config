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
#   - Top + bottom panels pinned to screen index 2 (FENNEC's M1)
#   - KWin rule: Beeper / Vesktop / Ferdium / Solaar start minimized
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
        # Pinned to screen index 2 — DRM enumeration on FENNEC is stable:
        # 0 = HDMI-A-1 (M3), 1 = DP-2 (M2), 2 = DP-3 (M1). Plasmashell
        # ignores the KScreen primary tag for panel containment placement,
        # so an explicit numeric index is the only reliable lever here.
        {
          location = "top";
          height = 28;
          lengthMode = "fill";
          floating = false;
          screen = 2;
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
        # Pinned to screen index 2 — see top panel comment for rationale.
        {
          location = "bottom";
          height = 56;
          floating = true;
          alignment = "center";
          lengthMode = "fit";
          hiding = "dodgewindows"; # slides away when a window touches it
          screen = 2;
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
      configFile."kwinrc"."Windows".Placement = "UnderMouse";

      # ── KWin window rules ────────────────────────────────────────────
      # Force tray-friendly Electron apps + Solaar to start minimized.
      # Their CLI flags (--start-minimized / --hidden / --window=hide)
      # aren't reliably honoured on Wayland, so a KWin rule is the only
      # stable mechanism. Substring match on wmclass to absorb the
      # lowercase/titlecase drift between Electron versions.
      #
      # rule schema (kwinrulesrc):
      #   wmclass         — substring to match against window class
      #   wmclasscomplete — match full class string (false = substring)
      #   wmclassmatch    — 1 = substring, 2 = regex, 3 = exact
      #   minimize        — true to enforce a minimized state
      #   minimizerule    — 3 = Force (always apply, ignore user toggles
      #                     for the initial state)
      configFile."kwinrulesrc" = {
        General = {
          count = 4;
          rules = "beeper,vesktop,ferdium,solaar";
        };
        beeper = {
          Description = "Start Beeper minimized";
          wmclass = "beeper";
          wmclasscomplete = false;
          wmclassmatch = 1;
          minimize = true;
          minimizerule = 3;
        };
        vesktop = {
          Description = "Start Vesktop minimized";
          wmclass = "vesktop";
          wmclasscomplete = false;
          wmclassmatch = 1;
          minimize = true;
          minimizerule = 3;
        };
        ferdium = {
          Description = "Start Ferdium minimized";
          wmclass = "ferdium";
          wmclasscomplete = false;
          wmclassmatch = 1;
          minimize = true;
          minimizerule = 3;
        };
        solaar = {
          Description = "Start Solaar minimized";
          wmclass = "solaar";
          wmclasscomplete = false;
          wmclassmatch = 1;
          minimize = true;
          minimizerule = 3;
        };
      };
    };
  };
}
