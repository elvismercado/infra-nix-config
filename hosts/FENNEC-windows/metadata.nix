# Cross-host metadata for FENNEC-windows (Windows side of the dual-boot
# box).
#
# Not built from this repo (`managed = false`) — declarative Windows
# config lives in the separate `elvismercado/windows-config` repository.
# The folder exists here only so this device participates in cross-host
# data (syncthing peer map, future wireguard peers, etc.).
#
# Public stub — privacy-sensitive fields (Syncthing device ID, per-peer
# LAN addresses) live in the sibling `nix-config-private` repo.
# Shares physical hardware with FENNEC, but Syncthing assigns a
# separate device ID per OS install.
{
  hostname = "FENNEC-windows";
  managed = false;
  os = "windows";
}
