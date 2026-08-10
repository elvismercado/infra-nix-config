# Plasma — macOS-style two-panel layout
# https://github.com/nix-community/plasma-manager
#
# Top panel: menu bar with kickerdash launcher, Global Menu, System Tray,
# Digital Clock, Show Desktop. Bottom panel: floating Icons-only dock.
# Used by JIN and FENNEC.
#
# Imports the shared baseline (`./common.nix`) and flips its `enable`
# automatically — hosts only set `custom.hmPlasmaMacos.enable = true`.
# Common's sub-options (systray.weather.enable, hotCorners.enable) are
# still set by the host because they're orthogonal to layout.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/plasma/macos.nix ];
#   custom.hmPlasmaMacos.enable = true;
#   custom.hmPlasmaCommon.systray.weather.enable = true;  # optional

{
  config,
  lib,
  plasmaCommon,
  ...
}:

let
  cfg = config.custom.hmPlasmaMacos;
in

{
  imports = [ ./common.nix ];

  options.custom.hmPlasmaMacos.enable = lib.mkEnableOption "macOS-style KDE Plasma layout (top menu bar with Global Menu, floating bottom dock)";

  config = lib.mkIf cfg.enable {
    custom.hmPlasmaCommon.enable = true;

    # Pinned to screen index 0 — in Plasma 6, panel screen ordinals follow
    # KScreen output priority. Hosts using this layout mark their primary
    # display as priority 1 in their display profile. Verify with
    # `kscreen-doctor -o` if a panel ever shows on the wrong monitor.
    programs.plasma.panels = [
      # Top panel — menu bar
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
              items = plasmaCommon.systrayItems;
            };
          }

          plasmaCommon.digitalClockWidget

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
        screen = 0;
        widgets = [
          {
            iconTasks = {
              launchers = [
                "applications:systemsettings.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:brave-browser.desktop"
              ];
            };
          }
        ];
      }
    ];
  };
}
