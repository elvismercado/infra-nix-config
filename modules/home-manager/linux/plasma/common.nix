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
#     Pins the weather widget to the systray's `shown` list (always
#     visible in the bar, not hidden in the popup). Requires
#     `userSettings.weatherLocation` (asserted) — typically supplied via
#     the private overlay in
#     `nix-config-private/hosts/<HOST>/user-settings.nix`:
#       weatherLocation = {
#         name = "The Hague";                              # human label, reference only
#         source = "wttr.in|weather|The Hague,NL";         # reference only (see KNOWN LIMITATION)
#         latitude = "52.0731027233998";                   # reference only
#         longitude = "4.292356634891381";                 # reference only
#         updateIntervalMinutes = 30;                       # reference only
#       };
#
#     KNOWN LIMITATION (TODO: revisit when plasma-manager fixes this):
#     Per-widget config for systray-embedded widgets (provider, location,
#     update interval) is NOT declaratively writable today.
#     plasma-manager's `systemTray.items.configs` option exists but its
#     convert function silently drops the values — KDE's plasma
#     scripting API can't reach into nested containments, and upstream's
#     `modules/widgets/system-tray.nix` has the relevant block commented
#     out with the note "Uncomment this if plasma scripting API ever
#     adds support for nested containments".
#     Consequence: the weather widget appears in the tray but shows
#     "no location configured" until the user right-clicks it and picks
#     a provider + location once. Plasma persists that choice across
#     reboots in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.
#     The `source` / `updateIntervalMinutes` / `latitude` / `longitude`
#     fields are kept in the overlay schema as inert reference data so
#     they're already in place once we can wire them — either when
#     upstream plasma-manager gains the capability, or via a
#     `home.activation` post-switch `kwriteconfig6` patcher (see TODO.md).
#
#   custom.hmPlasmaCommon.hotCorners.enable (default: true)
#     When `false`, disables all four screen-edge "hot corner" actions
#     (Overview, Activities, etc.). Useful on hosts where accidental
#     corner triggers are more annoying than useful.
#
#   custom.hmPlasmaCommon.singleClickToOpen (default: true)
#     When `false`, files and folders open on double-click and a
#     single-click only selects (Windows / macOS Finder behavior).
#     Useful on hosts whose primary user expects desktop-OS click
#     semantics rather than KDE's default web-style single-click.
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
    # NOTE: per-widget config (e.g. weather provider/location) cannot be
    # set declaratively here — plasma-manager silently drops
    # `systemTray.items.configs` for nested-containment widgets. See the
    # KNOWN LIMITATION block in this file's header. User configures the
    # weather widget once via right-click → Configure; Plasma persists
    # the choice in `plasma-org.kde.plasma.desktop-appletsrc`.
    configs = { };
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

    singleClickToOpen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, files and folders open on double-click and a
        single-click only selects them (Windows / macOS Finder
        behavior). When `true` (KDE default), a single-click opens.
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
      # NOTE: no assertion on `weather.source` — the field is currently
      # inert reference data (see KNOWN LIMITATION in header). Re-enable
      # an assertion when we wire the activation-script patcher.
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
        clickItemTo = if cfg.singleClickToOpen then "open" else "select";
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
