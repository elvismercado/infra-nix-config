# Cross-host metadata for LaJuvePixel9 (Android phone).
#
# Not built from this repo (`managed = false`). The folder exists only
# so this device participates in cross-host data (syncthing peer map,
# etc.). LAN IP is pinned for fast-path sync when the phone is home;
# `dynamic` covers off-LAN roaming via global discovery + relays.
{
  hostname = "LaJuvePixel9";
  managed = false;
  os = "android";
  lanIp = "192.168.1.31";

  syncthing = {
    id = "E2ZNFF2-ETJJVFF-YJSXZFR-F6RLEOV-PU4H3YK-QRGKIII-UT25YSO-NWJLCAU";
    addresses = [
      "tcp://192.168.1.31:22000"
      "dynamic"
    ];
  };
}
