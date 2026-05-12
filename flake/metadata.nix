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
# ## Public/private split
#
# Each host's metadata is split across two repos:
#
#   - PUBLIC stub   — `hosts/<HOST>/metadata.nix` in THIS repo. Holds
#                     non-sensitive descriptors: `hostname`, `managed`,
#                     `os`.
#   - PRIVATE overlay — `hosts/<HOST>/metadata.nix` in the sibling
#                     `nix-config-private` repo (expected at
#                     `../nix-config-private/` relative to this repo
#                     root). Holds privacy-sensitive fields like
#                     Syncthing device IDs and per-peer LAN addresses.
#
# This loader merges the private overlay on top of the public stub via
# `lib.recursiveUpdate` (private wins). When the private sibling is
# absent (CI, fresh checkout, outside contributor), the merge is a
# no-op and the loader returns the public stubs unchanged. Consumers
# like `syncthing-peers.nix` already filter out peers without an `id`,
# so a missing private repo degrades to an empty peer map rather than
# a build failure.
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

  public = lib.genAttrs hostNames (name: import (hostsDir + "/${name}/metadata.nix"));

  # Sibling private repo. Path literal resolves at flake-eval time;
  # `builtins.pathExists` returns `false` cleanly when the sibling is
  # absent, so this is pure-eval safe.
  privateMetadata = ../../nix-config-private/metadata.nix;
  private =
    if builtins.pathExists privateMetadata
    then import privateMetadata { inherit lib; }
    else { };

  all = lib.mapAttrs
    (name: pub: lib.recursiveUpdate pub (private.${name} or { }))
    public;

  managed = lib.filterAttrs (_: m: m.managed or false) all;
in
{
  inherit all managed;
}
