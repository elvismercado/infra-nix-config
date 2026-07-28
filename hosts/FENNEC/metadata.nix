# Cross-host metadata for FENNEC (Linux side of the dual-boot box).
#
# Public stub — privacy-sensitive fields (Syncthing device ID,
# per-peer LAN addresses) live in `infra-nix-config-private`. Their intended
# merge is currently deferred; see `flake/metadata.nix` and `TODO.md`.
#
# NOTE: The Windows side of the same physical machine is its own peer
# with a separate device ID — defined entirely in the private repo at
# `infra-nix-config-private/hosts/FENNEC-windows/metadata.nix` (no public
# stub, see `flake/metadata.nix` header).
{
  hostname = "FENNEC";
  managed = true;
  os = "nixos";
}
