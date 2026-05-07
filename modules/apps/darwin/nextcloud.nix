# Nextcloud — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `nextcloud` AND wires the
# matching home-manager wrapper under `custom.appNextcloud.enable`. Hosts
# should not also touch `homebrew.casks` for nextcloud or
# `custom.hmNextcloud.enable` directly.
#
# The HM darwin wrapper currently has no per-OS config (account configuration
# is GUI-only on darwin); the wrapper is pulled in for OS-symmetric host
# wiring and as a future hook.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/nextcloud.nix ];
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
  options.custom.appNextcloud.enable =
    lib.mkEnableOption "Nextcloud desktop sync client (Homebrew cask + HM wrapper)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "nextcloud" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/nextcloud.nix ];
      custom.hmNextcloud.enable = true;
    };
  };
}
