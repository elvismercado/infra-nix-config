# Cross-host metadata for JIN.
#
# Public stub — privacy-sensitive fields (Syncthing device ID,
# per-peer LAN addresses) live in `infra-nix-config-private`. Their intended
# merge is currently deferred; see `flake/metadata.nix` and `TODO.md`.
{
  hostname = "JIN";
  managed = true;
  os = "nixos";
}
