# Sweet Home 3D — Linux app façade (install-only)
#
# Cross-layer module that installs the Sweet Home 3D interior-design app
# under one host-facing toggle (`custom.appSweetHome3d.enable`) shared with
# the darwin façade.
#
# nixpkgs ships Sweet Home 3D as an attrset with `.application` (main
# authoring app), `.tools`, and `.editors` — we install only the
# authoring application here, matching what the cask provides.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/sweet-home3d.nix ];
#   custom.appSweetHome3d.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appSweetHome3d;
in
{
  options.custom.appSweetHome3d.enable = lib.mkEnableOption "Sweet Home 3D interior-design app (nixpkgs sweethome3d.application, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.sweethome3d.application ];
  };
}
