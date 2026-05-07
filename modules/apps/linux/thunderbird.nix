# Thunderbird — Linux app façade
#
# Cross-layer module that wires Thunderbird under
# `custom.appThunderbird.enable`. On Linux the binary comes from nixpkgs via
# home-manager (`programs.thunderbird` enabled with a default profile), so
# this façade is a thin forwarder.
#
# Hosts should not also touch `custom.hmThunderbird.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/thunderbird.nix ];
#   custom.appThunderbird.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appThunderbird;
in
{
  options.custom.appThunderbird.enable =
    lib.mkEnableOption "Thunderbird email client (nixpkgs binary + declarative profile)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/thunderbird.nix ];
      custom.hmThunderbird.enable = true;
    };
  };
}
