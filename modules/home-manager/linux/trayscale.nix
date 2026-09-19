# Trayscale — GTK system-tray front-end for Tailscale (Linux), with optional autostart.
#
# Tailscale ships no official GUI for Linux (the client is CLI-only:
# `tailscaled` + `tailscale`). Trayscale is a community GTK4/libadwaita app
# that adds a system-tray icon and window for connect/disconnect, peer list,
# copy-IP, and exit-node selection. It drives the same `tailscaled`, so it
# layers cleanly on top of the system module `custom.sysNixTailscale`.
#
# Needs a system tray (StatusNotifierItem). All hosts wiring this run KDE
# Plasma, which provides one. Its `autostart` option starts it minimised to
# tray on login with exec `trayscale --hide-window`.
#
# This module adds the package and owns its optional login autostart entry; the
# daemon comes from the NixOS `custom.sysNixTailscale` module.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/trayscale.nix ];
#   custom.hmTrayscale.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmTrayscale;
in
{
  imports = [ ./autostart.nix ];

  options.custom.hmTrayscale = {
    enable = lib.mkEnableOption "Trayscale (GTK system-tray front-end for the Tailscale CLI client)";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Trayscale in the system tray with the graphical session.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.trayscale ];

    custom.hmAutostart = lib.mkIf cfg.autostart {
      enable = true;
      entries.trayscale = {
        name = "Trayscale";
        exec = "trayscale --hide-window";
        icon = "dev.deltadev.trayscale";
      };
    };
  };
}
