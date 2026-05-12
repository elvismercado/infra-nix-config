# mpv — Linux app façade
#
# Cross-layer module that wires mpv under `custom.appMpv.enable`. On
# Linux the binary comes from nixpkgs via home-manager (no system-layer
# requirement), so this façade is a thin forwarder: it pulls the matching
# HM wrapper into HM scope and flips its enable toggle.
#
# Hosts should not also touch `custom.hmMpv.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/mpv.nix ];
#   custom.appMpv.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appMpv;
in
{
  options.custom.appMpv.enable = lib.mkEnableOption "mpv keyboard-driven video player (nixpkgs mpv)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/mpv.nix ];
      custom.hmMpv.enable = true;
    };
  };
}
