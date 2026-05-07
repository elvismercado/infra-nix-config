# Ferdium — Darwin app façade (install-only)
#
# Cross-layer module that installs the Ferdium cask under one host-facing
# toggle (`custom.appFerdium.enable`) shared with the Linux façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/ferdium.nix ];
#   custom.appFerdium.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appFerdium;
in
{
  options.custom.appFerdium.enable = lib.mkEnableOption "Ferdium multi-service web-app shell (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "ferdium" ];
  };
}
