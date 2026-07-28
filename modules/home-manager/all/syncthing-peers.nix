# Syncthing peers — projection over per-host metadata.
#
# Reads `flake/metadata.nix`, projects each host's `syncthing` block
# into the shape expected by `services.syncthing.settings.devices`:
# `{ id, addresses }`. Filters:
#
# Current limitation: normal flake evaluation cannot reach the loader's
# relative private-sibling path, so only public stubs are visible and this
# projection is empty. Wiring metadata through `inputs.private` is in TODO.md.
#
#   - Drops self (any peer whose attrset key matches `userSettings.hostname`).
#     This is what makes the SAME peers file safe to consume on every host.
#   - Drops peers without a captured `syncthing.id`. Lets us stage TODO
#     peers in the metadata files (commented-out IDs) without breaking
#     the build; once an ID is captured the peer appears automatically.
#
# Returns an attrset suitable for direct use as
# `services.syncthing.settings.devices`.
#
# Internal — imported by `modules/home-manager/all/syncthing.nix`.

{ lib, userSettings }:

let
  metadata = (import ../../../flake/metadata.nix { inherit lib; }).all;

  hasId = _: m: (m.syncthing or { }) ? id;
  notSelf = name: _: name != userSettings.hostname;

  eligible = lib.filterAttrs (n: m: notSelf n m && hasId n m) metadata;
in
lib.mapAttrs (_: m: {
  inherit (m.syncthing) id addresses;
}) eligible
