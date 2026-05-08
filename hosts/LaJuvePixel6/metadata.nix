# Cross-host metadata for LaJuvePixel6 (Android phone).
#
# Not built from this repo (`managed = false`). The folder exists only
# so this device participates in cross-host data (syncthing peer map,
# etc.). LAN IP is pinned for fast-path sync when the phone is home;
# `dynamic` covers off-LAN roaming via global discovery + relays.
{
  hostname = "LaJuvePixel6";
  managed = false;
  os = "android";
  lanIp = "192.168.1.30";

  syncthing = {
    # TODO: capture from Web UI → Actions → Show ID
    # id = "...";
    addresses = [
      "tcp://192.168.1.30:22000"
      "dynamic"
    ];
  };
}
