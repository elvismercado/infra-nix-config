# Sweet Home 3D — Darwin app façade (install-only)
#
# Cross-layer module that installs the Sweet Home 3D cask under one
# host-facing toggle (`custom.appSweetHome3d.enable`) shared with the Linux
# façade.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/sweet-home3d.nix ];
#   custom.appSweetHome3d.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appSweetHome3d;
in
{
  options.custom.appSweetHome3d.enable =
    lib.mkEnableOption "Sweet Home 3D interior-design app (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "sweet-home3d" ];
  };
}
