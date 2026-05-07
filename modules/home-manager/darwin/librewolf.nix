# LibreWolf — Darwin wrapper for the cross-platform librewolf core module.
#
# Binary is provided by the Homebrew cask `librewolf` (declared by the
# Option 3 app façade in `modules/apps/darwin/librewolf.nix`). This wrapper
# enables `programs.librewolf` with `package = null`, so home-manager writes
# `~/Library/Application Support/LibreWolf/librewolf.overrides.cfg` (when
# `custom.hmLibrewolf.settings` is non-empty) without installing a second
# LibreWolf copy from nixpkgs.
#
# This is the canonical "Option 2 cask + module coexistence (a)" pattern:
# `programs.<x>.package = null` is accepted by the upstream HM module
# (LibreWolf's package option is typed `nullOr package` and the module
# guards `cfg.finalPackage != null` before using it). Compare with VS Code,
# which rejects `package = null` and uses the `home.file` bypass instead.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/librewolf.nix`. Hosts should normally not import this
# file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/darwin/librewolf.nix ];
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
      package = null; # Cask provides the binary
      settings = cfg.settings;
    };
  };
}
