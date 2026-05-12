# Cross-host metadata for FENNEC (Linux side of the dual-boot box).
#
# Public stub — privacy-sensitive fields (Syncthing device ID,
# per-peer LAN addresses) live in the sibling `nix-config-private`
# repo and are merged in at flake-eval time. See `flake/metadata.nix`.
#
# NOTE: The Windows side of the same physical machine is its own peer
# with a separate device ID — see `hosts/FENNEC-windows/metadata.nix`.
{
  hostname = "FENNEC";
  managed = true;
  os = "nixos";
}
