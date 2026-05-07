# Syncthing — Linux wrapper for the cross-platform syncthing core module.
#
# Enables `services.syncthing` with the system tray icon, non-overriding
# device/folder semantics (so devices and folders added via the Web UI
# persist across rebuilds), and the shared cross-host policy: opt-out of
# anonymous telemetry, no daemon self-upgrade (nix owns the binary), and
# no auto-created `~/Sync` default folder on first launch.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/syncthing.nix` (toggle `custom.appSyncthing.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/syncthing.nix ];
#   custom.hmSyncthing.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmSyncthing;
in
{
  imports = [ ../core/syncthing.nix ];

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      tray = {
        enable = true;
      };
      overrideDevices = false; # If set to false, devices added via the web interface will persist and will have to be deleted manually.
      overrideFolders = false; # If set to false, folders added via the web interface will persist and will have to be deleted manually.
      extraOptions = [ "--no-default-folder" ]; # skip auto-creating the ~/Sync "Default" folder on first launch
      settings.options = {
        urAccepted = -1; # Opt out of anonymous usage reporting (-1 = declined)
        localAnnounceEnabled = true;
        autoUpgradeIntervalH = 0; # Disable daemon self-upgrade — nix owns the binary; channel-driven updates only
      };
    };
  };
}
