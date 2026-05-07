# cameractrls — Linux camera controls utility
#
# GTK app for adjusting v4l2 camera settings (exposure, focus, pan/tilt,
# H.264 bitrate, etc.) that aren't exposed by most video apps. No macOS
# counterpart, so this stays a Linux-only HM module rather than an app
# façade.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/cameractrls.nix ];
#   custom.hmCameractrls.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.custom.hmCameractrls.enable =
    lib.mkEnableOption "cameractrls (Linux v4l2 camera controls GUI)";

  config = lib.mkIf config.custom.hmCameractrls.enable {
    home.packages = [ pkgs.cameractrls ];
  };
}
