# OpenLogi — Linux app façade
#
# Installs OpenLogi through its upstream NixOS module, including the package,
# udev permissions, and graphical-session user service. OpenLogi manages its
# own device profiles through the app and its TOML configuration.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/openlogi.nix ];
#   custom.appOpenLogi.enable = true;

{
  config,
  inputs,
  lib,
  ...
}:

let
  cfg = config.custom.appOpenLogi;
in
{
  imports = [ inputs.openlogi.nixosModules.default ];

  options.custom.appOpenLogi.enable = lib.mkEnableOption "OpenLogi Logitech device manager (upstream NixOS module, install-only)";

  config = lib.mkIf cfg.enable {
    programs.openlogi = {
      enable = true;
      launchAtLogin = true;
    };
  };
}