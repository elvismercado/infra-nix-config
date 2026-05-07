# Syncthing — Linux app façade
#
# Cross-layer module that wires the Syncthing daemon under
# `custom.appSyncthing.enable`. On Linux the daemon comes from nixpkgs via
# the home-manager `services.syncthing` service (with system tray + opt-out
# telemetry), so this façade is a thin forwarder: it pulls the matching HM
# wrapper into HM scope and flips its enable toggle.
#
# Hosts should not also touch `custom.hmSyncthing.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/syncthing.nix ];
#   custom.appSyncthing.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appSyncthing;
in
{
  options.custom.appSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (nixpkgs services.syncthing + tray)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/syncthing.nix ];
      custom.hmSyncthing.enable = true;
    };
  };
}
