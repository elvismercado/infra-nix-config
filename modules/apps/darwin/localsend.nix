# LocalSend — Darwin app façade (install-only)
#
# Cross-layer module that installs LocalSend (cross-platform AirDrop
# alternative) under one host-facing toggle (`custom.appLocalsend.enable`)
# shared with the Linux façade. No home-manager `programs.*` config to
# wrap — LocalSend manages its own settings through the in-app UI.
#
# On darwin the binary comes from the Homebrew cask `localsend`.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/localsend.nix ];
#   custom.appLocalsend.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appLocalsend;
in
{
  options.custom.appLocalsend.enable =
    lib.mkEnableOption "LocalSend (cross-platform file sharing — Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "localsend" ];
  };
}
