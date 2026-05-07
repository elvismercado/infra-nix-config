# Beeper — Darwin app façade (install-only)
#
# Cross-layer module that installs the Beeper cask under one host-facing
# toggle (`custom.appBeeper.enable`) shared with the Linux façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/beeper.nix ];
#   custom.appBeeper.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appBeeper;
in
{
  options.custom.appBeeper.enable =
    lib.mkEnableOption "Beeper unified-messaging client (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "beeper" ];
  };
}
