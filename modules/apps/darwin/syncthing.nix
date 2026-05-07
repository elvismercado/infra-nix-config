# Syncthing — Darwin app façade
#
# Forwarder over the unified `modules/home-manager/all/syncthing.nix`.
# The Syncthing daemon comes from `pkgs.syncthing` and is run as a per-user
# LaunchAgent by home-manager's `services.syncthing` (no Homebrew cask, no
# menubar wrapper). The `custom.appSyncthing.enable` toggle name is
# preserved for symmetry with the Linux façade and host-config stability.
#
# Trade-off vs the previous cask-based setup: no menubar status icon on
# darwin (upstream HM puts an `assertPlatform = linux` on
# `services.syncthing.tray`). The Web UI desktop shortcut
# (`~/Desktop/Syncthing Web UI.webloc`) is the canonical entry point.
# Previous cask-based setup is preserved under
# `.archive/syncthing-2026-05-08/` if a rollback is ever needed.
#
# Hosts should not also touch `custom.hmSyncthing.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/syncthing.nix ];
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
