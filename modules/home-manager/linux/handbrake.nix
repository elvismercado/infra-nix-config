# HandBrake — Linux wrapper for the cross-platform handbrake core module.
#
# Installs `pkgs.handbrake` (the GUI transcoder) into home.packages.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/handbrake.nix` (toggle `custom.appHandbrake.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/handbrake.nix ];
#   custom.hmHandbrake.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmHandbrake;
in
{
  imports = [ ../core/handbrake.nix ];

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.handbrake
    ];
  };
}
