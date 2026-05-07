# LocalSend — Linux app façade (install-only)
#
# Cross-layer module that installs LocalSend (cross-platform AirDrop
# alternative) under one host-facing toggle (`custom.appLocalsend.enable`)
# shared with the darwin façade. No home-manager `programs.*` config to
# wrap — LocalSend manages its own settings through the in-app UI.
#
# On Linux the binary comes from nixpkgs `localsend`.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/localsend.nix ];
#   custom.appLocalsend.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appLocalsend;
in
{
  options.custom.appLocalsend.enable =
    lib.mkEnableOption "LocalSend (cross-platform file sharing — nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.localsend ];
  };
}
