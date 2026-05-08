# Cross-host metadata for YUNA (server, Unraid).
#
# Not built from this repo (`managed = false`) — Unraid is configured
# out-of-band. The folder exists here only so this device participates
# in cross-host data (syncthing peer map, future wireguard peers, etc.).
{
  hostname = "YUNA";
  managed = false;
  os = "unraid";
  lanIp = "192.168.40.2";

  syncthing = {
    id = "E25DNYB-DE2F5OY-TYRHNUN-SX35WGX-7PU7ZMZ-FODTFYT-PZ3MOUH-KFNU5AL";
    addresses = [
      "tcp://192.168.40.2:22000"
      "dynamic"
    ];
  };
}
