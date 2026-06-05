# RustDesk — Linux app façade (install-only)
#
# Cross-layer module that installs the RustDesk remote-desktop client/host
# under one host-facing toggle (`custom.appRustdesk.enable`) shared with the
# darwin façade. RustDesk is an open-source TeamViewer/AnyDesk alternative —
# the same binary acts as both the controlled host and the controlling
# client, so a single install covers remote-support in either direction.
#
# nixpkgs ships it as `pkgs.rustdesk`. TEMPORARY: that attribute (1.4.6) fails
# to build on Linux (nixpkgs#527155 — non-deterministic cargo-vendor FOD hash;
# fix queued in PR #527831, 1.4.6 → 1.4.7). As an interim we use the separate
# `pkgs.rustdesk-flutter` attribute (1.4.5), which predates the break. Revert
# to `pkgs.rustdesk` once the 1.4.7 backport reaches 26.05.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/rustdesk.nix ];
#   custom.appRustdesk.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appRustdesk;
in
{
  options.custom.appRustdesk.enable = lib.mkEnableOption "RustDesk remote-desktop client/host (nixpkgs rustdesk-flutter, install-only)";

  config = lib.mkIf cfg.enable {
    # TEMPORARY: rustdesk-flutter (1.4.5) until pkgs.rustdesk (1.4.6) builds
    # again — see header + nixpkgs#527155 / PR #527831.
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.rustdesk-flutter ];
  };
}
