# OpenLogi — Darwin app façade (install-only)
#
# Installs the native OpenLogi app through its official Homebrew cask under
# the same `custom.appOpenLogi.enable` toggle used on Linux. OpenLogi manages
# its own device profiles through the app and its TOML configuration.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/openlogi.nix ];
#   custom.appOpenLogi.enable = true;

{ config, lib, ... }:

let
  cfg = config.custom.appOpenLogi;
in
{
  options.custom.appOpenLogi.enable = lib.mkEnableOption "OpenLogi Logitech device manager (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "openlogi" ];
  };
}