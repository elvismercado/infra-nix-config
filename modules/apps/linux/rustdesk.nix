# RustDesk — Linux app façade (install-only)
#
# Cross-layer module that installs the RustDesk remote-desktop client/host
# under one host-facing toggle (`custom.appRustdesk.enable`) shared with the
# darwin façade. RustDesk is an open-source TeamViewer/AnyDesk alternative —
# the same binary acts as both the controlled host and the controlling
# client, so a single install covers remote-support in either direction.
#
# nixpkgs ships it as `pkgs.rustdesk`.
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
  options.custom.appRustdesk.enable = lib.mkEnableOption "RustDesk remote-desktop client/host (nixpkgs rustdesk, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.rustdesk ];
  };
}
