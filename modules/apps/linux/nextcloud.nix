# Nextcloud — Linux app façade
#
# Cross-layer module that wires the Nextcloud desktop client under
# `custom.appNextcloud.enable`. On Linux the binary comes from nixpkgs via
# the home-manager `services.nextcloud-client` service (started by systemd
# user unit, includes tray + autostart), so this façade is a thin forwarder:
# it pulls the matching HM wrapper into HM scope and flips its enable toggle.
#
# Hosts should not also touch `custom.hmNextcloud.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/nextcloud.nix ];
#   custom.appNextcloud.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appNextcloud;
in
{
  options.custom.appNextcloud.enable = lib.mkEnableOption "Nextcloud desktop sync client (nixpkgs services.nextcloud-client)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/nextcloud.nix ];
      custom.hmNextcloud.enable = true;
    };
  };
}
