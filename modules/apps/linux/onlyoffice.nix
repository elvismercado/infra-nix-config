# OnlyOffice Desktop Editors — Linux app façade (install-only)
#
# Cross-layer module that installs ONLYOFFICE Desktop Editors under one
# host-facing toggle (`custom.appOnlyoffice.enable`) shared with the darwin
# façade. No home-manager `programs.*` config to wrap — OnlyOffice manages
# its own settings through the in-app UI and ~/.config/onlyoffice.
#
# On Linux the binary comes from nixpkgs `onlyoffice-desktopeditors`
# (x86_64-linux only).
#
# Notes:
#   - UI language and spell-check dictionaries are bundled in a single binary
#     (~46 languages incl. English/Dutch/Spanish). Pick the active language
#     per-user via Settings → Interface language. There is no flake-level
#     `langs` knob to wire.
#   - Papiamentu (`pap`) is NOT supported upstream — no UI translation in
#     ONLYOFFICE/desktop-apps and no `pap_*` Hunspell dictionary in the
#     bundled `dictionaries` submodule. Tracked as an upstream gap.
#   - AI features ship as an on-demand plugin from the in-app Marketplace;
#     not installed by default. No flag needed to "disable" AI.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/onlyoffice.nix ];
#   custom.appOnlyoffice.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appOnlyoffice;
in
{
  options.custom.appOnlyoffice.enable = lib.mkEnableOption "ONLYOFFICE Desktop Editors (nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.onlyoffice-desktopeditors ];
  };
}
