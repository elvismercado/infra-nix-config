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
# ## Intended public/private split
#
# Hosts come in two flavours:
#
#   - MANAGED hosts (built from this repo). Their metadata is split:
#       * PUBLIC stub   — `hosts/<HOST>/metadata.nix` in THIS repo,
#                         alongside `configuration/` and `home-manager/`.
#                         Holds non-sensitive descriptors: `hostname`,
#                         `managed = true`, `os`.
#       * PRIVATE overlay — `hosts/<HOST>/metadata.nix` in the authenticated
#                         `infra-nix-config-private` flake input. Holds
#                         privacy-sensitive fields like
#                         Syncthing device IDs and per-peer LAN addresses.
#
#   - UNMANAGED hosts (Unraid boxes, phones, the Windows side of a
#     dual-boot, etc.). Their metadata lives ENTIRELY in the private
#     repo — there is no matching public stub. The loader unions in
#     any host present only on the private side so these still surface
#     in cross-host data (e.g. the syncthing peer map).
#
# The private source is passed explicitly from the flake input so evaluation
# works from the Nix store copy. Callers may omit it for public-only metadata.
#
# Returns:
#   {
#     all     = <attrset of every host's metadata, keyed by directory>;
#     managed = <subset where `managed = true`>;
#   }

{ lib, privateSource ? null }:

let
  hostsDir = ../hosts;

  entries = builtins.readDir hostsDir;

  hasMetadata = name: type:
    type == "directory" && builtins.pathExists (hostsDir + "/${name}/metadata.nix");

  publicHostNames = builtins.attrNames (lib.filterAttrs hasMetadata entries);

  public = lib.genAttrs publicHostNames (name: import (hostsDir + "/${name}/metadata.nix"));

  privateMetadata =
    if privateSource == null then null else privateSource + "/metadata.nix";
  private =
    if privateMetadata != null && builtins.pathExists privateMetadata
    then import privateMetadata { inherit lib; }
    else { };

  # Union of host names across public stubs and private-only entries.
  # Hosts present only in private (unmanaged: Unraid, phones, the
  # Windows side of dual-boot, …) get an empty public base and inherit
  # everything from the private overlay.
  allHostNames =
    lib.unique (publicHostNames ++ builtins.attrNames private);

  all = lib.genAttrs allHostNames
    (name: lib.recursiveUpdate (public.${name} or { }) (private.${name} or { }));

  managed = lib.filterAttrs (_: m: m.managed or false) all;
in
{
  inherit all managed;
}
