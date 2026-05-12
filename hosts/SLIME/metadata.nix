# Cross-host metadata for SLIME (NAS, Unraid).
#
# Not built from this repo (`managed = false`) — Unraid is configured
# out-of-band. The folder exists here only so this device participates
# in cross-host data (syncthing peer map, future wireguard peers, etc.).
#
# Public stub — privacy-sensitive fields (Syncthing device ID, per-peer
# LAN addresses) live in the sibling `nix-config-private` repo.
{
  hostname = "SLIME";
  managed = false;
  os = "unraid";
}
