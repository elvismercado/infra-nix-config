# Shared per-host metadata loader.
#
# Auto-discovers every directory under `hosts/` that contains a
# `metadata.nix` and exposes the result as a single attrset keyed by
# directory name. Consumers (e.g. `modules/home-manager/all/syncthing-peers.nix`)
# project the fields they care about; this loader is intentionally
# generic and knows nothing about syncthing/wireguard/etc.
#
# Adding a new device = drop a `hosts/<NAME>/metadata.nix` file. No
# registry edit required here. Note that the flake builders in
# `flake/hosts.nix` are an explicit registry — only nix-managed hosts
# listed there are ever built. The `managed` flag in metadata is for
# documentation and future tooling, not load-bearing for builds.
#
# Returns:
#   {
#     all     = <attrset of every host's metadata, keyed by directory>;
#     managed = <subset where `managed = true`>;
#   }

{ lib }:

let
  hostsDir = ../hosts;

  entries = builtins.readDir hostsDir;

  hasMetadata = name: type:
    type == "directory" && builtins.pathExists (hostsDir + "/${name}/metadata.nix");

  hostNames = builtins.attrNames (lib.filterAttrs hasMetadata entries);

  all = lib.genAttrs hostNames (name: import (hostsDir + "/${name}/metadata.nix"));

  managed = lib.filterAttrs (_: m: m.managed or false) all;
in
{
  inherit all managed;
}
