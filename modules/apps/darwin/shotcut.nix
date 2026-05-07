# Shotcut — Darwin app façade (install-only)
#
# Cross-layer module that installs the Shotcut cask under one host-facing
# toggle (`custom.appShotcut.enable`) shared with the Linux façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/shotcut.nix ];
#   custom.appShotcut.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appShotcut;
in
{
  options.custom.appShotcut.enable =
    lib.mkEnableOption "Shotcut video editor (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "shotcut" ];
  };
}
