# HandBrake — Linux app façade
#
# Cross-layer module that wires HandBrake under `custom.appHandbrake.enable`.
# On Linux the binary comes from nixpkgs via home-manager (no system-layer
# requirement), so this façade is a thin forwarder: it pulls the matching
# HM wrapper into HM scope and flips its enable toggle.
#
# Hosts should not also touch `custom.hmHandbrake.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/handbrake.nix ];
#   custom.appHandbrake.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appHandbrake;
in
{
  options.custom.appHandbrake.enable =
    lib.mkEnableOption "HandBrake video transcoder GUI (nixpkgs handbrake)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/handbrake.nix ];
      custom.hmHandbrake.enable = true;
    };
  };
}
