# Raspberry Pi Imager — Linux app façade (install-only)
#
# Cross-layer module that installs Raspberry Pi Imager under one host-facing
# toggle (`custom.appRpiImager.enable`) shared with the darwin façade. No
# settings to manage — it's a one-shot SD-card flasher.
#
# On Linux the binary comes from nixpkgs `rpi-imager`.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/rpi-imager.nix ];
#   custom.appRpiImager.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appRpiImager;
in
{
  options.custom.appRpiImager.enable =
    lib.mkEnableOption "Raspberry Pi Imager (nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.rpi-imager ];
  };
}
