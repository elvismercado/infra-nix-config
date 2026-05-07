# Raspberry Pi Imager — Darwin app façade (install-only)
#
# Cross-layer module that installs Raspberry Pi Imager under one host-facing
# toggle (`custom.appRpiImager.enable`) shared with the Linux façade. No
# settings to manage — it's a one-shot SD-card flasher.
#
# On darwin the binary comes from the Homebrew cask `raspberry-pi-imager`
# (note the cask name differs from the Linux nixpkgs attribute `rpi-imager`).
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/rpi-imager.nix ];
#   custom.appRpiImager.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appRpiImager;
in
{
  options.custom.appRpiImager.enable = lib.mkEnableOption "Raspberry Pi Imager (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "raspberry-pi-imager" ];
  };
}
