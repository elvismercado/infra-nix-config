# Ferdium — Linux app façade with optional login autostart
#
# Cross-layer module that installs the Ferdium multi-service web-app shell
# under one host-facing toggle (`custom.appFerdium.enable`) shared with the
# darwin façade. Configured through its own UI — no HM `programs.*` to wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/ferdium.nix ];
#   custom.appFerdium.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appFerdium;
in
{
  options.custom.appFerdium = {
    enable = lib.mkEnableOption "Ferdium multi-service web-app shell (nixpkgs)";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Ferdium hidden with the graphical session.";
    };
  };

  config = lib.mkMerge [
    {
      home-manager.users.${userSettings.username}.imports = [ ../../home-manager/linux/autostart.nix ];
    }
    (lib.mkIf cfg.enable {
      home-manager.users.${userSettings.username} = {
        home.packages = [ pkgs.ferdium ];

        custom.hmAutostart = lib.mkIf cfg.autostart {
          enable = true;
          entries.ferdium = {
            name = "Ferdium";
            exec = "ferdium --hidden";
            icon = "ferdium";
          };
        };
      };
    })
  ];
}
