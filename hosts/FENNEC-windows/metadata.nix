# Cross-host metadata for FENNEC-windows (Windows side of the dual-boot
# box).
#
# Not built from this repo (`managed = false`) — declarative Windows
# config lives in the separate `elvismercado/windows-config` repository.
# The folder exists here only so this device participates in cross-host
# data (syncthing peer map, future wireguard peers, etc.).
#
# Shares physical hardware (and therefore the LAN IP) with FENNEC, but
# Syncthing assigns a separate device ID per OS install.
{
  hostname = "FENNEC-windows";
  managed = false;
  os = "windows";
  lanIp = "192.168.20.40";

  syncthing = {
    # TODO: capture from Web UI → Actions → Show ID (boot into Windows)
    # id = "...";
    addresses = [
      "tcp://192.168.20.40:22000"
      "dynamic"
    ];
  };
}
