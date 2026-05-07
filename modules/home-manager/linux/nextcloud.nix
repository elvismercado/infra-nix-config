# Nextcloud — Linux wrapper for the cross-platform nextcloud core module.
#
# Enables `services.nextcloud-client` — the systemd user service that runs
# the desktop sync client with tray icon and autostart.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/nextcloud.nix` (toggle `custom.appNextcloud.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/nextcloud.nix ];
#   custom.hmNextcloud.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmNextcloud;
in
{
  imports = [ ../core/nextcloud.nix ];

  config = lib.mkIf cfg.enable {
    services.nextcloud-client = {
      enable = true;
    };
  };
}
