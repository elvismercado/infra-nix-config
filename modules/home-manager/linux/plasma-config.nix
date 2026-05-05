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
#   - Top + bottom panels pinned to screen index 0 (KScreen priority 1 = M1 on FENNEC)
#   - KWin rule: Steam / Beeper / Vesktop / Ferdium / Solaar start minimized
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
        # Pinned to screen index 0 — in Plasma 6, panel screen ordinals
        # follow KScreen output priority. The host's display profile
        # marks M1 (DP-3) as priority 1, which Plasma exposes as
        # screen 0. Verify with `kscreen-doctor -o` if it ever moves.
        {
          location = "top";
          height = 28;
          lengthMode = "fill";
          floating = false;
          screen = 0;
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
        # Pinned to screen index 0 — see top panel comment for rationale.
        {
          location = "bottom";
          height = 56;
          floating = true;
          alignment = "center";
          lengthMode = "fit";
          hiding = "dodgewindows"; # slides away when a window touches it
          screen = 0;
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
      # Force tray-friendly Electron apps + Steam + Solaar to start
      # minimized. Their CLI flags (--start-minimized / --hidden /
      # -silent / --window=hide) aren't reliably honoured on Wayland,
      # so a KWin rule is the only stable mechanism. Regex match
      # (wmclassmatch=2) with case-flexible patterns absorbs the case
      # drift between apps (e.g. "Vesktop" vs "vesktop").
      #
      # rule schema (kwinrulesrc):
      #   wmclass         — pattern matched against window class
      #   wmclasscomplete — false: match either WM_CLASS field
      #   wmclassmatch    — 1 = substring, 2 = regex, 3 = exact
      #   minimize        — true to enforce a minimized state
      #   minimizerule    — 3 = Force (always apply, ignore user toggles
      #                     for the initial state)
      configFile."kwinrulesrc" = {
        General = {
          count = 5;
          rules = "steam,beeper,vesktop,ferdium,solaar";
        };
        steam = {
          Description = "Start Steam minimized";
          wmclass = "^[Ss]team$";
          wmclasscomplete = false;
          wmclassmatch = 2;
          minimize = true;
          minimizerule = 3;
        };
        beeper = {
          Description = "Start Beeper minimized";
          wmclass = "[Bb]eeper";
          wmclasscomplete = false;
          wmclassmatch = 2;
          minimize = true;
          minimizerule = 3;
        };
        vesktop = {
          Description = "Start Vesktop minimized";
          wmclass = "[Vv]esktop";
          wmclasscomplete = false;
          wmclassmatch = 2;
          minimize = true;
          minimizerule = 3;
        };
        ferdium = {
          Description = "Start Ferdium minimized";
          wmclass = "[Ff]erdium";
          wmclasscomplete = false;
          wmclassmatch = 2;
          minimize = true;
          minimizerule = 3;
        };
        solaar = {
          Description = "Start Solaar minimized";
          wmclass = "[Ss]olaar";
          wmclasscomplete = false;
          wmclassmatch = 2;
          minimize = true;
          minimizerule = 3;
        };
      };
    };
  };
}
