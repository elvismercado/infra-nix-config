# Signal Desktop — Darwin app façade (install-only)
#
# Cross-layer module that installs the Signal Desktop cask under one
# host-facing toggle (`custom.appSignal.enable`) shared with the Linux façade.
# No home-manager `programs.*` config to wrap — Signal stores its profile
# inside its own Electron data directory, configured through the in-app UI.
#
# On darwin the binary comes from the Homebrew cask `signal` (gives Spotlight,
# Gatekeeper, and auto-update). Per repo convention, GUI apps on macOS go
# through casks, never nixpkgs.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/signal-desktop.nix ];
#   custom.appSignal.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appSignal;
in
{
  options.custom.appSignal.enable =
    lib.mkEnableOption "Signal Desktop (secure messaging — Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "signal" ];
  };
}
