# Spotify — Linux app façade (install-only)
#
# Cross-layer module that installs the Spotify binary under one host-facing
# toggle (`custom.appSpotify.enable`) shared with the darwin façade. No
# home-manager `programs.*` config to wrap — Spotify settings are managed
# through the in-app UI and the user's Spotify account.
#
# On Linux the binary comes from nixpkgs `spotify` (unfree), installed into
# the configured user's home-manager packages so it shows up in launchers
# without touching system-wide `environment.systemPackages`.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/spotify.nix ];
#   custom.appSpotify.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appSpotify;
in
{
  options.custom.appSpotify.enable =
    lib.mkEnableOption "Spotify (music streaming — nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.spotify ];
  };
}
