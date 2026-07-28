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
#   - Click-to-focus pinned explicitly (defensive - already the KDE
#     default, but pinned so a future Plasma default flip doesn't
#     silently switch parent-style hosts to focus-follows-mouse)
#   - Notification popup timeout bumped from 5s to 10s (gives slower
#     readers enough time to finish a notification before it vanishes)
#   - Desktop icons arranged top-to-bottom, left-aligned
#   - Webcamoid (Qt webcam app, replaces Kamoso)
#   - Plasma config CLI tools (`kreadconfig6`, `kwriteconfig6`, `kcmshell6`)
#     on `PATH` for inspecting / scripting `kdeglobals` and `*rc` files
#     and for launching individual KCMs (e.g. `kcmshell6 kcm_fonts`).
#
# Opt-in feature toggles:
#   custom.hmPlasmaCommon.systray.weather.enable (default: true)
#     Pins the weather widget to the systray's `shown` list (always
#     visible in the bar, not hidden in the popup). Defaults to `true`
#     on every Plasma host; set `false` on hosts that don't want it,
#     or that don't have `userSettings.weatherLocation`. Requires
#     `userSettings.weatherLocation` when `true` (asserted) — typically
#     supplied via the private overlay in
#     `infra-nix-config-private/hosts/<HOST>/user-settings.nix`:
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
#   custom.hmPlasmaCommon.cursor.enable (default: false)
#     When `true`, applies a parent-friendly cursor preset:
#     `Breeze_Snow` theme at 36px with a "Bouncing" click-feedback
#     pulse. Bigger cursor is easier to track; the click pulse cuts
#     down on rapid-fire double/triple-click reflex.
#
#   custom.hmPlasmaCommon.confirmLogout.enable (default: false)
#     When `true`, Plasma asks for confirmation (with a 30-second
#     countdown auto-cancel) before logout / restart / shutdown.
#
#   custom.hmPlasmaCommon.dolphin.enable (default: false)
#     When `true`, writes a curated `dolphinrc` preset aimed at less
#     technical users: full path in the title bar, status bar visible,
#     archive browsing, file-picker defaulting to Details view, and
#     "open externally-called folder in existing window" behaviour
#     (closest declarative thing to single-window mode - the tabs
#     feature itself cannot be hidden declaratively). Hover tooltips
#     are governed by the separate `dolphin.showToolTips` sub-option
#     (default off because KDE's tooltip-show delay for Dolphin's KIO
#     file tooltips is hardcoded too short to be useful, and there is
#     no declarative key to slow it down). Hosts where the popup
#     speed is acceptable can opt back in.
#
#   custom.hmPlasmaCommon.dolphin.showToolTips (default: false)
#     Only applies when `dolphin.enable` is `true`. Flip to `true` to
#     re-enable Dolphin's hover file tooltips. LULA leaves this off;
#     FENNEC and JIN turn it on.
#
#   custom.hmPlasmaCommon.quickTile.shortcuts.enable (default: true)
#     When `false`, unbinds KWin's Quick Tile keyboard shortcuts (the
#     eight Meta+arrow / diagonal combos) plus Meta+Up (Maximize) and
#     Meta+Down (Minimize). Quick Tile capability stays available
#     from the window menu and System Settings; only the
#     accidental-trigger keyboard surface goes away. Useful on hosts
#     where bumping the Meta key during normal typing makes windows
#     jump unexpectedly.
#
#   custom.hmPlasmaCommon.quickTile.edgeDrag.enable (default: true)
#     When `false`, disables KWin's drag-to-edge tiling and the
#     drag-to-top-edge maximize gesture. Independent from
#     `quickTile.shortcuts.enable` so hosts can leave edge-drag on as
#     a discoverable / learnable gesture while still suppressing the
#     accidental keyboard triggers.
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

    systray.weather.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `true` (default), pins the weather widget to the systray's
        `shown` list (always visible in the bar). Requires
        `userSettings.weatherLocation` to be set (asserted); typically
        supplied via the private overlay. Set `false` on Plasma hosts
        that don't want the widget or that have no location overlay.
      '';
    };

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

    cursor.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, applies a parent-friendly cursor preset: the
        `Breeze_Snow` theme at 36px with a "Bouncing" click-feedback
        pulse. Larger cursor is easier to track on a high-DPI laptop
        panel; the click pulse confirms the click registered, which
        cuts down on the rapid-fire double/triple-click reflex.
      '';
    };

    confirmLogout.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, Plasma asks for confirmation (with a 30-second
        countdown auto-cancel) before logout / restart / shutdown.
        Prevents accidental session loss from a stray click in the
        power menu.
      '';
    };

    dolphin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When `true`, writes a curated `dolphinrc` preset aimed at
        less technical users: full path in the title bar, status bar
        visible, archive browsing, file picker defaulting to Details
        view, and "open externally-called folder in existing window"
        behaviour (closest declarative approximation of single-window
        mode - Dolphin's tabs feature itself has no kill switch).
        Hover file tooltips are governed by the separate
        `dolphin.showToolTips` sub-option.
      '';
    };

    dolphin.showToolTips = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Only applies when `dolphin.enable` is `true`. When `false`
        (default), Dolphin's hover file tooltips are suppressed -
        KDE's tooltip-show delay for Dolphin's KIO tooltips is
        hardcoded too short to be useful for non-technical users and
        there is no declarative key to slow it down. Flip to `true`
        on hosts where the popup speed is acceptable.
      '';
    };

    quickTile.shortcuts.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, unbinds KWin's Quick Tile keyboard shortcuts
        (the eight Meta+arrow / diagonal combos) plus Meta+Up
        (Maximize) and Meta+Down (Minimize). Quick Tile capability
        remains available from the window menu and System Settings;
        only the accidental-trigger keyboard surface is removed.
      '';
    };

    quickTile.edgeDrag.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, disables KWin's drag-to-edge tiling
        (`ElectricBorderTiling`) and the drag-to-top-edge maximize
        gesture (`ElectricBorderMaximize`). Independent from
        `quickTile.shortcuts.enable` so hosts can leave edge-drag
        snapping on as a discoverable / learnable gesture while still
        suppressing the accidental keyboard triggers.
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
        message = "custom.hmPlasmaCommon.systray.weather.enable requires userSettings.weatherLocation (typically set in infra-nix-config-private/hosts/<HOST>/user-settings.nix)";
      }
      # NOTE: no assertion on `weather.source` — the field is currently
      # inert reference data (see KNOWN LIMITATION in header). Re-enable
      # an assertion when we wire the activation-script patcher.
    ];

    home.packages = [
      pkgs.webcamoid
      # Plasma config CLI tools — kreadconfig6 / kwriteconfig6 (from
      # kconfig) for reading/writing kdeglobals and *rc files from the
      # shell; kcmshell6 (from kcmutils) for opening individual KCMs
      # (e.g. `kcmshell6 kcm_fonts`).
      pkgs.kdePackages.kconfig
      pkgs.kdePackages.kcmutils
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
      }
      // lib.optionalAttrs cfg.cursor.enable {
        # Parent-friendly cursor: bigger + visible click feedback.
        cursor = {
          theme = "Breeze_Snow";
          size = 36;
          cursorFeedback = "Bouncing";
        };
      };

      session = {
        sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";
      }
      // lib.optionalAttrs cfg.confirmLogout.enable {
        general.askForConfirmationOnLogout = true;
      };

      desktop.icons = {
        arrangement = "topToBottom";
        alignment = "left";
        lockInPlace = false;
      };

      configFile = {
        "kwinrc"."Windows" = {
          Placement = "UnderMouse";
          # Pin click-to-focus explicitly. Already the KDE default;
          # writing it defensively so a future upstream default flip
          # (e.g. to FocusFollowsMouse) can't silently change behaviour
          # on parent-style hosts.
          FocusPolicy = "ClickToFocus";
        };
        # Bump notification popup timeout from the 5s default to 10s.
        # Cheap quality-of-life win on every Plasma host - slower
        # readers get enough time to finish a notification before it
        # vanishes; faster readers can still dismiss manually.
        "plasmanotifyrc"."Notifications".PopupTimeout = 10000;
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
      }
      # Dolphin preset - sensible defaults for non-technical users.
      # `OpenExternallyCalledFolderInNewTab=false` is the closest
      # declarative thing to "single-window mode": when another app
      # asks the desktop to open a folder (e.g. browser "Show in
      # folder"), Dolphin focuses an existing window/tab instead of
      # spawning a new one. Dolphin's own Ctrl+T tabs remain available.
      // lib.optionalAttrs cfg.dolphin.enable {
        "dolphinrc"."General" = {
          BrowseThroughArchives = true;
          ShowFullPath = true;
          ShowToolTips = cfg.dolphin.showToolTips;
          ShowStatusBar = true;
          OpenExternallyCalledFolderInNewTab = false;
          RememberOpenedTabs = false;
        };
        "dolphinrc"."KFileDialog Settings"."View Style" = "DetailsView";
      }
      # Edge-drag tiling kill switch. Disables both drag-to-side
      # (tile to half-screen) and drag-to-top (maximize). The Meta+
      # keyboard shortcuts are unbound separately via the
      # `programs.plasma.shortcuts` block below when
      # `quickTile.shortcuts.enable` is `false`.
      // lib.optionalAttrs (!cfg.quickTile.edgeDrag.enable) {
        "kwinrc"."Windows".ElectricBorderTiling = false;
        "kwinrc"."Windows".ElectricBorderMaximize = false;
      };

      # Quick Tile keyboard shortcut kill switch. `mkForce` because
      # plasma-manager seeds defaults at a lower priority - a plain
      # assignment might not win the merge. Empty list = unbound.
      shortcuts = lib.mkIf (!cfg.quickTile.shortcuts.enable) {
        "kwin" = {
          "Window Quick Tile Left" = lib.mkForce [ ];
          "Window Quick Tile Right" = lib.mkForce [ ];
          "Window Quick Tile Top" = lib.mkForce [ ];
          "Window Quick Tile Bottom" = lib.mkForce [ ];
          "Window Quick Tile Top Left" = lib.mkForce [ ];
          "Window Quick Tile Top Right" = lib.mkForce [ ];
          "Window Quick Tile Bottom Left" = lib.mkForce [ ];
          "Window Quick Tile Bottom Right" = lib.mkForce [ ];
          "Window Maximize" = lib.mkForce [ ];
          "Window Minimize" = lib.mkForce [ ];
        };
      };
    };
  };
}
