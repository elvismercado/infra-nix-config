# Signal Desktop — Linux app façade (install-only)
#
# Cross-layer module that installs the Signal Desktop binary under one
# host-facing toggle (`custom.appSignal.enable`) shared with the darwin façade.
# No home-manager `programs.*` config to wrap — Signal stores its profile
# inside its own Electron data directory, configured through the in-app UI.
#
# On Linux the binary comes from nixpkgs `signal-desktop`, installed into the
# configured user's home-manager packages so it shows up in launchers without
# touching system-wide `environment.systemPackages`.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/signal-desktop.nix ];
#   custom.appSignal.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appSignal;
in
{
  options.custom.appSignal.enable = lib.mkEnableOption "Signal Desktop (secure messaging — nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.signal-desktop ];
  };
}
