# Trayscale — GTK system-tray front-end for Tailscale (Linux).
#
# Tailscale ships no official GUI for Linux (the client is CLI-only:
# `tailscaled` + `tailscale`). Trayscale is a community GTK4/libadwaita app
# that adds a system-tray icon and window for connect/disconnect, peer list,
# copy-IP, and exit-node selection. It drives the same `tailscaled`, so it
# layers cleanly on top of the system module `custom.sysNixTailscale`.
#
# Needs a system tray (StatusNotifierItem). All hosts wiring this run KDE
# Plasma, which provides one. Start it minimised to tray on login via
# `custom.hmAutostart.entries` with exec `trayscale --hide-window`.
#
# Install-only — this module just adds the package; the daemon comes from
# the NixOS `custom.sysNixTailscale` module.
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

{
  options.custom.hmTrayscale.enable =
    lib.mkEnableOption "Trayscale (GTK system-tray front-end for the Tailscale CLI client)";

  config = lib.mkIf config.custom.hmTrayscale.enable {
    home.packages = [ pkgs.trayscale ];
  };
}
