# LibreWolf — Linux wrapper for the cross-platform librewolf core module.
#
# Installs LibreWolf from nixpkgs via home-manager and feeds the shared
# `custom.hmLibrewolf.settings` attrset (declared in `core/librewolf.nix`)
# to `programs.librewolf.settings`. HM writes
# `~/.librewolf/librewolf.overrides.cfg` only when settings is non-empty.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/librewolf.nix` (toggle `custom.appLibrewolf.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/librewolf.nix ];
#   custom.hmLibrewolf.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmLibrewolf;
in
{
  imports = [ ../core/librewolf.nix ];

  config = lib.mkIf cfg.enable {
    programs.librewolf = {
      enable = true;
      settings = cfg.settings;
    };
  };
}
