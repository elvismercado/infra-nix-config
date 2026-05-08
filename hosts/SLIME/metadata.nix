# Cross-host metadata for SLIME (NAS, Unraid).
#
# Not built from this repo (`managed = false`) — Unraid is configured
# out-of-band. The folder exists here only so this device participates
# in cross-host data (syncthing peer map, future wireguard peers, etc.).
{
  hostname = "SLIME";
  managed = false;
  os = "unraid";
  lanIp = "192.168.60.3";

  syncthing = {
    id = "R6BJ3B2-4DBFOBI-TFGJK57-MPXDQDK-VDUNUI2-J2EKL3K-4UTZJA4-SXWD5AJ";
    addresses = [
      "tcp://192.168.60.3:22000"
      "dynamic"
    ];
  };
}
