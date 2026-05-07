# LibreOffice — Linux app façade (install-only)
#
# Cross-layer module that installs the LibreOffice suite under one host-facing
# toggle (`custom.appLibreoffice.enable`) shared with the darwin façade. No
# home-manager `programs.*` config to wrap — LibreOffice manages its own
# settings through the in-app UI and ~/.config/libreoffice.
#
# On Linux the binary comes from nixpkgs `libreoffice` (the still / LTS
# branch). Switch to `libreoffice-fresh` here if a host wants the newer
# release branch.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/libreoffice.nix ];
#   custom.appLibreoffice.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appLibreoffice;
in
{
  options.custom.appLibreoffice.enable = lib.mkEnableOption "LibreOffice suite (nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.libreoffice ];
  };
}
