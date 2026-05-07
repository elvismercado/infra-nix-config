# Steam — Darwin app façade (install-only)
#
# Cross-layer module that installs the Steam cask under one host-facing
# toggle (`custom.appSteam.enable`) shared with the Linux façade. There is
# no HM-side declarative config to wrap on darwin — Steam settings are
# managed through the in-app UI and the user's Steam account.
#
# On darwin the binary comes from the Homebrew cask `steam` (gives
# Spotlight, Gatekeeper, and auto-update). Per repo convention, GUI apps
# on macOS go through casks, never nixpkgs.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/steam.nix ];
#   custom.appSteam.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appSteam;
in
{
  options.custom.appSteam.enable = lib.mkEnableOption "Steam (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "steam" ];
  };
}
