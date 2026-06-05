# Wake-on-LAN (magic packet) for wired NetworkManager connections.
#
# Sets `ethernet.wake-on-lan = magic` as a NetworkManager-wide default,
# so every wired connection profile applies it at activation (and
# re-applies on reconnect, link bounce, suspend/resume). This is more
# robust than `networking.interfaces.<iface>.wakeOnLan.enable`, which
# fires once via a oneshot ethtool service and can be reverted by NM
# on the next reconnect.
#
# BIOS prerequisites (one-time, per host):
#   - ErP / Deep Sleep / "EuP Ready"      = Disabled
#       (otherwise S5 cuts power to the NIC and magic packets never arrive)
#   - "Wake on LAN" / "Resume by PCI-E"   = Enabled
#       (board-specific menu name; usually under Power Management or APM)
#
# Verification after a switch:
#   nmcli -f connection.id,ethernet.wake-on-lan connection show
#   nix shell nixpkgs#ethtool -c sudo ethtool <iface> | grep -i wake-on   # expect: Wake-on: g
#
# Wake from a peer on the same L2 segment:
#   nix run nixpkgs#wakeonlan -- <MAC>
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/network/wake-on-lan.nix ];
#   custom.sysNixWakeOnLan.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixWakeOnLan;
in
{
  options.custom.sysNixWakeOnLan = {
    enable = lib.mkEnableOption "Wake-on-LAN (magic packet) for wired NetworkManager connections";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.connectionConfig."ethernet.wake-on-lan" = "magic";
  };
}
