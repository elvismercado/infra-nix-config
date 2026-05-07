# Syncthing — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `syncthing-app` AND wires
# the matching home-manager wrapper under `custom.appSyncthing.enable`. The
# cask is the menubar GUI and owns the daemon + autostart on darwin (there
# is no `services.syncthing` analogue on macOS in nix-darwin/HM).
#
# Hosts should not also touch `homebrew.casks` for syncthing-app or
# `custom.hmSyncthing.enable` directly.
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
  options.custom.appSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (Homebrew cask syncthing-app)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "syncthing-app" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/syncthing.nix ];
      custom.hmSyncthing.enable = true;
    };
  };
}
