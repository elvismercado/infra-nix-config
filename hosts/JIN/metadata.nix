# Cross-host metadata for JIN.
#
# Public stub — privacy-sensitive fields (Syncthing device ID,
# per-peer LAN addresses) live in the sibling `nix-config-private`
# repo and are merged in at flake-eval time. See `flake/metadata.nix`.
{
  hostname = "JIN";
  managed = true;
  os = "nixos";
}
