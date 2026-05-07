# Spotify — Darwin app façade (install-only)
#
# Cross-layer module that installs the Spotify cask under one host-facing
# toggle (`custom.appSpotify.enable`) shared with the Linux façade. No
# home-manager `programs.*` config to wrap — Spotify settings are managed
# through the in-app UI and the user's Spotify account.
#
# On darwin the binary comes from the Homebrew cask `spotify` (gives
# Spotlight, Gatekeeper, and auto-update). Per repo convention, GUI apps
# on macOS go through casks, never nixpkgs.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/spotify.nix ];
#   custom.appSpotify.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appSpotify;
in
{
  options.custom.appSpotify.enable =
    lib.mkEnableOption "Spotify (music streaming — Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "spotify" ];
  };
}
