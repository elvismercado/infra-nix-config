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
#         name = "The Hague";                              # human label, not read by widget
#         source = "wttr.in|weather|The Hague,NL";         # REQUIRED
#         latitude = "52.0731027233998";                   # reference only
#         longitude = "4.292356634891381";                 # reference only
#         updateIntervalMinutes = 30;                       # optional, default 60
#       };
#     `source` is the literal value the KDE weather applet writes to
#     `[Configuration][WeatherStation] source=` in its appletsrc entry.
#     Format is `<provider>|weather|<location-id>`. wttr.in is the
#     simplest provider — location id is just `City,CC` (or any string
#     wttr.in accepts; see `wttr.in/:help`). For bbcukmet / noaa /
#     envcan you typically have to configure the widget once via the
#     GUI on a throwaway machine, then read the resulting `source=`
#     line out of `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.
#     `latitude`/`longitude` are kept in the overlay as inert reference
#     data — not consumed by the widget, useful if we ever wire a
#     different provider or a 3rd-party widget that needs coordinates.
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
        # `source` is the verbatim key the KDE weather applet reads.
        # Format: "<provider>|weather|<location-id>". See header.
        source = weather.source;
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

    kwallet.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, disables the KWallet daemon entirely (writes
        `Enabled=false` to `kwalletrc`) and suppresses the first-run
        wizard. Without a Secret Service agent running, NetworkManager
        falls back to its own keyfile store for Wi-Fi PSKs (saved under
        `/etc/NetworkManager/system-connections/`, root-readable), which
        avoids the well-known "Wi-Fi waits for authentication but no
        prompt appears" deadlock when KWallet is uninitialized.

        Saved Wi-Fi networks that were previously stored in KWallet must
        be forgotten and re-added once after flipping this off, so that
        plasma-nm rewrites them to the system keyfile.
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
      {
        assertion = !weatherEnabled || weather == null || (weather ? source);
        message = "userSettings.weatherLocation.source is required when custom.hmPlasmaCommon.systray.weather.enable = true. Format: \"<provider>|weather|<location-id>\", e.g. \"wttr.in|weather|The Hague,NL\".";
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
      # KWallet kill switch — disable the daemon and suppress the
      # first-run wizard. Without a Secret Service agent, plasma-nm /
      # NetworkManager fall back to the system keyfile store for Wi-Fi
      # PSKs, which is what we want on hosts where nobody asked for a
      # password manager UI.
      // lib.optionalAttrs (!cfg.kwallet.enable) {
        "kwalletrc"."Wallet" = {
          "Enabled" = false;
          "First Use" = false;
        };
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
