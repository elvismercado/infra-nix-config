# LibreOffice — Darwin app façade (install-only)
#
# Cross-layer module that installs the LibreOffice suite under one host-facing
# toggle (`custom.appLibreoffice.enable`) shared with the Linux façade. No
# home-manager `programs.*` config to wrap — LibreOffice manages its own
# settings through the in-app UI.
#
# On darwin the binary comes from the Homebrew cask `libreoffice` (gives
# Spotlight, Gatekeeper, and auto-update).
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/libreoffice.nix ];
#   custom.appLibreoffice.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appLibreoffice;
in
{
  options.custom.appLibreoffice.enable =
    lib.mkEnableOption "LibreOffice suite (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "libreoffice" ];
  };
}
