# Plasma — LULA layout
# https://github.com/nix-community/plasma-manager
#
# A two-panel layout aimed at parents and older relatives: larger panels,
# no Global Menu (per-window menu bars stay where users expect them), and
# a bottom dock that mixes pinned launchers with running app icons.
# Used by LULA. Reusable for any host that fits the same persona.
#
# Top panel: kickerdash launcher button, flexible spacer, System Tray,
# Digital Clock, Show Desktop. No Global Menu.
# Bottom panel: floating dock with Icons-only Task Manager (pinned +
# running apps).
#
# Imports the shared baseline (`./common.nix`) and flips its `enable`
# automatically. Recommended companion settings on the host:
#   custom.hmPlasmaCommon.systray.weather.enable = true;
#   custom.hmPlasmaCommon.hotCorners.enable      = false;
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/plasma/lula.nix ];
#   custom.hmPlasmaLula.enable = true;

{
  config,
  lib,
  plasmaCommon,
  ...
}:

let
  cfg = config.custom.hmPlasmaLula;
in

{
  imports = [ ./common.nix ];

  options.custom.hmPlasmaLula.enable = lib.mkEnableOption "LULA KDE Plasma layout (parent-friendly: top tray panel + bottom dock, no Global Menu)";

  config = lib.mkIf cfg.enable {
    custom.hmPlasmaCommon.enable = true;

    programs.plasma.panels = [
      # Top panel — launcher + tray. Slightly taller than macos's top
      # panel for easier targeting on a single 14" laptop screen.
      {
        location = "top";
        height = 36;
        lengthMode = "fill";
        floating = false;
        widgets = [
          # Application Dashboard — full-screen grid, easy for users
          # unfamiliar with cascading menus. Lives in the top-left
          # corner; the classic Kickoff menu sits in the bottom-left
          # corner of the bottom dock as an alternative launcher
          # (and as the de-facto power menu, since Kickerdash exposes
          # only Leave/Restart/Shutdown).
          "org.kde.plasma.kickerdash"

          # Flexible spacer pushes the rest to the right
          "org.kde.plasma.panelspacer"

          # System Tray — network, volume, notifications, weather, etc.
          {
            systemTray = {
              icons.scaleToFit = true;
              items = plasmaCommon.systrayItems;
            };
          }

          plasmaCommon.digitalClockWidget

          # Peek at / show desktop
          "org.kde.plasma.showdesktop"
        ];
      }

      # Bottom panel — full-width dock with pinned launchers + running
      # apps. `iconTasks` shows both pinned (.desktop launchers) and
      # currently running windows in a single strip, so the user has one
      # place to see "what can I open" and "what's open right now".
      # Non-floating + `lengthMode = "fill"` gives a true edge-to-edge
      # taskbar; `dodgewindows` lets maximized apps reclaim the full
      # screen height. Two flanking expanding panel spacers center the
      # task icons within the full-width panel — `alignment` has no
      # effect when the panel is in fill mode. Kickoff sits flush-left
      # — outside the centered group — so it doesn't shift the visual
      # center of the iconTasks strip.
      #
      # TEMPORARY EXPERIMENT (2026-05-20): a second task strip using the
      # classic `org.kde.plasma.taskmanager` (icons + window-title text,
      # one button per window) is wired alongside `iconTasks` for A/B
      # comparison. iconTasks remains the primary muscle-memory strip;
      # the labelled strip is purely additive so the user can decide
      # which mode she prefers. To revert: delete the second iconTasks
      # block below (the one with `iconsOnly = false`).
      {
        location = "bottom";
        height = 56;
        floating = false;
        lengthMode = "fill";
        hiding = "dodgewindows";
        widgets = [
          # Classic Kickoff menu in the bottom-left corner. Familiar
          # Windows-Start-style launcher and the full session/power
          # button row (Lock, Logout, Switch User, Suspend, Hibernate,
          # Reboot, Shutdown) which Kickerdash does not expose.
          "org.kde.plasma.kickoff"
          { panelSpacer = { expanding = true; }; }
          {
            iconTasks = {
              launchers = [
                "applications:systemsettings.desktop"
                "applications:org.kde.dolphin.desktop"
                "preferred://browser"
              ];
            };
          }
          # Experimental classic task manager (icons + window titles,
          # one button per window). Same plasma-manager `iconTasks`
          # shorthand, but `iconsOnly = false` flips the emitted plasmoid
          # to `org.kde.plasma.taskmanager`. No `launchers` here — the
          # icon-only strip above already owns the pinned launchers, so
          # this strip shows only running windows. `grouping.method =
          # "none"` forces one button per window (the whole point of
          # the experiment).
          {
            iconTasks = {
              iconsOnly = false;
              behavior.grouping.method = "none";
            };
          }
          { panelSpacer = { expanding = true; }; }
        ];
      }
    ];

    # UI fonts — Plasma 6 defaults plus exactly +2pt across every
    # category. A single conservative step up that preserves KDE's
    # intended size hierarchy (small still ~80% of general, window
    # title still bold) and gives the 14" 1080p panel a bit of breathing
    # room without fighting Plasma's pixel-perfect layouts. For stronger
    # magnification the user can layer a global UI scale on top via
    # System Settings (see "Display scaling" in
    # `hosts/LULA/README.md`).
    programs.plasma.fonts = {
      general = {
        family = "Noto Sans";
        pointSize = 12;
      };
      menu = {
        family = "Noto Sans";
        pointSize = 12;
      };
      toolbar = {
        family = "Noto Sans";
        pointSize = 12;
      };
      windowTitle = {
        family = "Noto Sans";
        pointSize = 12;
        weight = "bold"; # matches Plasma 6 default (WM.activeFont is bold)
      };
      small = {
        family = "Noto Sans";
        pointSize = 10;
      };
      fixedWidth = {
        family = "Hack Nerd Font";
        pointSize = 12;
      };
    };
  };
}
