# Syncthing — Linux app façade
#
# Forwarder over the unified `modules/home-manager/all/syncthing.nix`.
# The Syncthing daemon comes from `pkgs.syncthing` via home-manager's
# `services.syncthing` (systemd user service + KDE tray icon). The
# `custom.appSyncthing.enable` toggle name is preserved for symmetry with
# the darwin façade and host-config stability.
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
  options.custom.appSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/all/syncthing.nix ];
      custom.hmSyncthing.enable = true;
    };
  };
}
