# mpv — Linux wrapper for the cross-platform mpv core module.
#
# Enables `programs.mpv` so nixpkgs `pkgs.mpv` lands in the user profile
# and the matching `.desktop` file registers with the desktop environment.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/mpv.nix` (toggle `custom.appMpv.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/mpv.nix ];
#   custom.hmMpv.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmMpv;
in
{
  imports = [ ../core/mpv.nix ];

  config = lib.mkIf cfg.enable {
    programs.mpv.enable = true;
  };
}
