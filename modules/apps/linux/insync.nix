# Insync — Linux app façade (install-only)
#
# Cross-layer module that installs Insync (Google Drive / OneDrive / Dropbox
# desktop sync) under one host-facing toggle (`custom.appInsync.enable`)
# shared with the darwin façade. Insync is proprietary (unfree) and
# configured entirely through its own UI (account login, per-folder rules)
# — no HM `programs.*` to wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/insync.nix ];
#   custom.appInsync.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appInsync;
in
{
  options.custom.appInsync.enable =
    lib.mkEnableOption "Insync (Google Drive / OneDrive / Dropbox sync — nixpkgs unfree, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.insync ];
  };
}
