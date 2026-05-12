# Cross-host metadata for FENNEC (Linux side of the dual-boot box).
#
# Public stub — privacy-sensitive fields (Syncthing device ID,
# per-peer LAN addresses) live in the sibling `nix-config-private`
# repo and are merged in at flake-eval time. See `flake/metadata.nix`.
#
# NOTE: The Windows side of the same physical machine is its own peer
# with a separate device ID — defined entirely in the private repo at
# `nix-config-private/hosts/FENNEC-windows/metadata.nix` (no public
# stub, see `flake/metadata.nix` header).
{
  hostname = "FENNEC";
  managed = true;
  os = "nixos";
}
