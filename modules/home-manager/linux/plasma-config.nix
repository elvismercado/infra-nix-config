# Plasma Desktop Configuration — modular KDE layouts + feature toggles
# https://github.com/nix-community/plasma-manager
#
# One module, two layouts, opt-in widgets. Hosts pick a layout via
# `custom.hmPlasmaConfig.layout` and switch features on/off independently.
#
# Layouts:
#   "macos"   — two panels: top menu bar (Global Menu, systray, clock)
#               + bottom floating dock (Icons-only Task Manager).
#               Default. Used by JIN/FENNEC.
#   "minimal" — single bottom floating panel: systray + clock only.
#               No top bar, no app dock. KRunner (Meta key) drives launches.
#               Used by LULA.
#
# Always-on tweaks (apply on every layout):
#   - KRunner centered (Spotlight-style)
#   - Single-click to open files/folders
#   - No splash screen (Plymouth handles boot splash)
#   - Login starts with empty session (no app restore)
#   - New windows open under the cursor (UnderMouse placement)
#   - Window buttons on the right
#
# Feature toggles:
#   custom.hmPlasmaConfig.systray.weather.enable
#     Adds the weather widget to the systray on either layout.
#     Requires `userSettings.weatherLocation` (asserted) — typically
#     supplied via the private overlay in
#     `nix-config-private/hosts/<HOST>/user-settings.nix`:
#       weatherLocation = {
#         name = "The Hague";              # station label shown in widget
#         latitude = "52.0731027233998";   # reserved for future provider wiring
#         longitude = "4.292356634891381"; # reserved for future provider wiring
#         updateIntervalMinutes = 30;       # optional, default 60
#       };
#     Station label and refresh interval are written declaratively;
#     the data provider (wttr.in / BBC / NOAA / ...) is picked manually
#     in the widget UI on first launch.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/plasma-config.nix ];
#   custom.hmPlasmaConfig.enable = true;
#   custom.hmPlasmaConfig.layout = "macos";              # or "minimal"
#   custom.hmPlasmaConfig.systray.weather.enable = true; # opt-in

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmPlasmaConfig;
  weather = userSettings.weatherLocation or null;
  weatherEnabled = cfg.systray.weather.enable;

  # Shared systray block — used by both layouts. The weather widget is
  # appended to `shown` only when the host opts in, and its config is
  # written to the standard Plasma 6 `[Configuration][WeatherStation]`
  # group via plasma-manager's raw-config passthrough.
  systrayItems = {
    shown =
      [
        "org.kde.plasma.bluetooth"
        "org.kde.plasma.cameraindicator"
        "org.kde.plasma.lock_keys"
      ]
      ++ lib.optional weatherEnabled "org.kde.plasma.weather";
    configs = lib.optionalAttrs weatherEnabled {
      "org.kde.plasma.weather".config.WeatherStation = {
        weatherStationName = weather.name;
        updateInterval = weather.updateIntervalMinutes or 60;
      };
    };
  };

  digitalClockWidget = {
    digitalClock = {
      calendar.firstDayOfWeek = "monday";
      time.format = "24h";
    };
  };

  # ── Layout: macOS ────────────────────────────────────────────────────
  # Two panels. Top hosts the Global Menu, kickerdash launcher, systray,
  # clock. Bottom is a floating icons-only dock.
  # Pinned to screen index 0 — in Plasma 6, panel screen ordinals follow
  # KScreen output priority. Hosts using this layout mark their primary
  # display as priority 1 in their display profile. Verify with
  # `kscreen-doctor -o` if a panel ever shows on the wrong monitor.
  panelsMacos = [
    {
      location = "top";
      height = 28;
      lengthMode = "fill";
      floating = false;
      screen = 0;
      widgets = [
        # App launcher — uncomment ONE of the following:
        # "org.kde.plasma.kickoff"        # Kickoff: traditional start menu
        # "org.kde.plasma.kicker"         # Application Menu: compact cascading menu
        "org.kde.plasma.kickerdash" # Application Dashboard: full-screen grid (Launchpad-style)

        # Global Menu — shows the focused window's menu bar
        "org.kde.plasma.appmenu"

        # Flexible spacer pushes the rest to the right
        "org.kde.plasma.panelspacer"

        # System Tray — network, volume, notifications, etc.
        {
          systemTray = {
            icons.scaleToFit = true;
            items = systrayItems;
          };
        }

        digitalClockWidget

        # Peek at / show desktop
        "org.kde.plasma.showdesktop"
      ];
    }

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

  # ── Layout: minimal ──────────────────────────────────────────────────
  # Single bottom floating panel — systray + clock only. No top bar, no
  # dock, no Global Menu. Apps are launched via KRunner (Meta key) or
  # the systray. Aimed at low-friction personas (LULA).
  panelsMinimal = [
    {
      location = "bottom";
      height = 32;
      floating = true;
      alignment = "center";
      lengthMode = "fit";
      hiding = "dodgewindows";
      widgets = [
        {
          systemTray = {
            icons.scaleToFit = true;
            items = systrayItems;
          };
        }
        digitalClockWidget
      ];
    }
  ];
in

{
  options.custom.hmPlasmaConfig = {
    enable = lib.mkEnableOption "opinionated KDE Plasma layout (macOS-style or minimal)";

    layout = lib.mkOption {
      type = lib.types.enum [
        "macos"
        "minimal"
      ];
      default = "macos";
      description = ''
        Panel layout to apply.
        - "macos": two panels (top menu bar + bottom floating dock).
        - "minimal": single bottom floating panel (systray + clock only).
      '';
    };

    systray.weather.enable = lib.mkEnableOption ''
      weather widget in the systray. Requires `userSettings.weatherLocation`
      (typically set via the private overlay)
    '';
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmPlasmaConfig requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
      {
        assertion = !weatherEnabled || weather != null;
        message = "custom.hmPlasmaConfig.systray.weather.enable requires userSettings.weatherLocation (typically set in nix-config-private/hosts/<HOST>/user-settings.nix)";
      }
    ];

    # Webcam app (Qt, replaces Kamoso)
    home.packages = [
      pkgs.webcamoid
    ];

    programs.plasma = {
      enable = true;

      panels = if cfg.layout == "macos" then panelsMacos else panelsMinimal;

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
    };
  };
}
