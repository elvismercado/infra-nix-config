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
          # unfamiliar with cascading menus.
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
      # screen height.
      {
        location = "bottom";
        height = 56;
        floating = false;
        lengthMode = "fill";
        hiding = "dodgewindows";
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

    # Larger UI fonts — default Plasma is 10pt Noto Sans, which is
    # tight on a 14" 1080p panel for a non-technical user. Bump the
    # main UI fonts to 12pt and the fixed-width font to 12pt as well
    # (Hack Nerd Font is pulled in by `custom.sysFonts`, matches what
    # Starship expects in the terminal).
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
