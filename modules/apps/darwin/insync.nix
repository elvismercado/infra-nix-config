# Insync — Darwin app façade (install-only)
#
# Cross-layer module that installs the Insync cask under one host-facing
# toggle (`custom.appInsync.enable`) shared with the Linux façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/insync.nix ];
#   custom.appInsync.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appInsync;
in
{
  options.custom.appInsync.enable = lib.mkEnableOption "Insync (Google Drive / OneDrive / Dropbox sync — Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "insync" ];
  };
}
