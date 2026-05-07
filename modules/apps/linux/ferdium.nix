# Ferdium — Linux app façade (install-only)
#
# Cross-layer module that installs the Ferdium multi-service web-app shell
# under one host-facing toggle (`custom.appFerdium.enable`) shared with the
# darwin façade. Configured through its own UI — no HM `programs.*` to wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/ferdium.nix ];
#   custom.appFerdium.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appFerdium;
in
{
  options.custom.appFerdium.enable =
    lib.mkEnableOption "Ferdium multi-service web-app shell (nixpkgs, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.ferdium ];
  };
}
