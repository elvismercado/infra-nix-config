# Plasma — shared baseline (always-on tweaks + opt-in widgets)
# https://github.com/nix-community/plasma-manager
#
# Internal — do not import from hosts. Imported by the per-layout files
# in this directory (`macos.nix`, `lula.nix`). Hosts pick a layout, not
# this file. The layout file flips `custom.hmPlasmaCommon.enable` for you.
#
# What this module owns (applies to every layout):
#   - `programs.plasma.enable`
#   - KWin titlebar buttons on the right
#   - KRunner centered (Spotlight-style)
#   - Single-click to open files/folders
#   - No splash screen (Plymouth handles boot splash)
#   - Login starts with empty session (no app restore)
#   - New windows open under the cursor (UnderMouse placement)
#   - Desktop icons arranged top-to-bottom, left-aligned
#   - Webcamoid (Qt webcam app, replaces Kamoso)
#
# Opt-in feature toggles:
#   custom.hmPlasmaCommon.systray.weather.enable
#     Adds the weather widget to the systray. Requires
#     `userSettings.weatherLocation` (asserted) — typically supplied via
#     the private overlay in
#     `nix-config-private/hosts/<HOST>/user-settings.nix`:
#       weatherLocation = {
#         name = "The Hague";              # station label shown in widget
#         latitude = "52.0731027233998";   # reserved for future provider wiring
#         longitude = "4.292356634891381"; # reserved for future provider wiring
#         updateIntervalMinutes = 30;       # optional, default 60
#       };
#     Only the station label and refresh interval are written
#     declaratively; the data provider (wttr.in / BBC / NOAA / ...) is
#     picked manually in the widget UI on first launch.
#
#   custom.hmPlasmaCommon.hotCorners.enable (default: true)
#     When `false`, disables all four screen-edge "hot corner" actions
#     (Overview, Activities, etc.). Useful on hosts where accidental
#     corner triggers are more annoying than useful.
#
# Helpers exposed to layout files (via `_module.args`):
#   plasmaCommon.systrayItems     — attrset for `systemTray.items` with
#                                    weather conditionally appended.
#   plasmaCommon.digitalClockWidget — pre-configured clock widget attrset.

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmPlasmaCommon;
  weather = userSettings.weatherLocation or null;
  weatherEnabled = cfg.systray.weather.enable;

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
in

{
  options.custom.hmPlasmaCommon = {
    enable = lib.mkEnableOption "shared KDE Plasma baseline (always-on tweaks consumed by layout modules)";

    systray.weather.enable = lib.mkEnableOption ''
      weather widget in the systray. Requires `userSettings.weatherLocation`
      (typically set via the private overlay)
    '';

    hotCorners.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, disables all four screen-edge "hot corner" actions
        (Overview, Activities, etc.). KDE's defaults are kept when `true`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Expose helpers to per-layout files via `_module.args`. Layout
    # modules read `plasmaCommon.systrayItems` / `plasmaCommon.digitalClockWidget`.
    _module.args.plasmaCommon = {
      inherit systrayItems digitalClockWidget;
    };

    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmPlasmaCommon requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
      {
        assertion = !weatherEnabled || weather != null;
        message = "custom.hmPlasmaCommon.systray.weather.enable requires userSettings.weatherLocation (typically set in nix-config-private/hosts/<HOST>/user-settings.nix)";
      }
    ];

    home.packages = [
      pkgs.webcamoid
    ];

    programs.plasma = {
      enable = true;

      kwin = {
        tiling.padding = 4;

        titlebarButtons = {
          left = [ ];
          right = [
            "minimize"
            "maximize"
            "close"
          ];
        };
      };

      krunner = {
        position = "center";
        historyBehavior = "enableSuggestions";
      };

      workspace = {
        clickItemTo = "open";
        splashScreen.theme = "None";
      };

      desktop.icons = {
        arrangement = "topToBottom";
        alignment = "left";
        lockInPlace = false;
      };

      session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

      configFile = {
        "kwinrc"."Windows".Placement = "UnderMouse";
      }
      # Hot-corner kill switch — disable all four screen edges. Value 9
      # corresponds to KWin's `ElectricBorder::ElectricNone` enum, which
      # tells the Overview effect not to bind to any edge. The
      # `[ElectricBorders]` block belt-and-braces silences anything else
      # that might try to claim a corner.
      // lib.optionalAttrs (!cfg.hotCorners.enable) {
        "kwinrc"."Effect-overview".BorderActivate = 9;
        "kwinrc"."ElectricBorders" = {
          TopLeft = "None";
          TopRight = "None";
          BottomLeft = "None";
          BottomRight = "None";
        };
      };
    };
  };
}
