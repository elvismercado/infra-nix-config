# Beeper — Linux app façade (install-only)
#
# Cross-layer module that installs the Beeper unified-messaging client under
# one host-facing toggle (`custom.appBeeper.enable`) shared with the darwin
# façade. Beeper is proprietary (unfree) and configured through its own UI
# (Matrix-based aggregator login per service) — no HM `programs.*` to wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/beeper.nix ];
#   custom.appBeeper.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appBeeper;
in
{
  options.custom.appBeeper.enable = lib.mkEnableOption "Beeper unified-messaging client (nixpkgs unfree, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.beeper ];
  };
}
