# OpenLogi — Linux app façade
# https://github.com/AprilNEA/OpenLogi
#
# Installs OpenLogi through its upstream NixOS module (from the `packaging/` directory),
# which includes:
#   - `openlogi` CLI — device inventory, diagnostics, firmware info
#   - `openlogi-agent` user service — background HID++ handling (starts with graphical-session.target)
#   - `openlogi-desktop` GUI — launched on demand (no system tray indicator on Linux)
#   - udev rules (`70-openlogi.rules`) — grants active-seat user write access to /dev/uinput
#     and read/write to /dev/hidraw* without sudo
#
# Prerequisites & operational notes:
#   - Solaar (or Logi Options+) must NOT be running concurrently; both fight for exclusive
#     HID++ communication with the Bolt/Unifying receiver.
#   - If devices are not detected immediately after initial activation, reconnect the receiver
#     or power-cycle wireless mice so udev re-evaluates the device ACLs.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/openlogi.nix ];
#   custom.appOpenLogi.enable = true;

{
  config,
  inputs,
  lib,
  ...
}:

let
  cfg = config.custom.appOpenLogi;
in
{
  imports = [ inputs.openlogi.nixosModules.default ];

  options.custom.appOpenLogi.enable = lib.mkEnableOption "OpenLogi Logitech device manager (upstream NixOS module, install-only)";

  config = lib.mkIf cfg.enable {
    programs.openlogi = {
      enable = true;
      launchAtLogin = true;
    };
  };
}