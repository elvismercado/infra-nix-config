# Shotcut — Linux app façade (install-only)
#
# Cross-layer module that installs the Shotcut video editor under one
# host-facing toggle (`custom.appShotcut.enable`) shared with the darwin
# façade.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/shotcut.nix ];
#   custom.appShotcut.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appShotcut;
in
{
  options.custom.appShotcut.enable =
    lib.mkEnableOption "Shotcut video editor (nixpkgs, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.shotcut ];
  };
}
