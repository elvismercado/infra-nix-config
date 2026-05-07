# Moonlight — Darwin app façade (install-only)
#
# Cross-layer module that installs the Moonlight cask under one host-facing
# toggle (`custom.appMoonlight.enable`) shared with the Linux façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/moonlight.nix ];
#   custom.appMoonlight.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appMoonlight;
in
{
  options.custom.appMoonlight.enable = lib.mkEnableOption "Moonlight game/desktop streaming client (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "moonlight" ];
  };
}
