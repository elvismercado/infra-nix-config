# Moonlight — Linux app façade (install-only)
#
# Cross-layer module that installs the Moonlight game/desktop streaming
# CLIENT under one host-facing toggle (`custom.appMoonlight.enable`) shared
# with the darwin façade. The complementary Moonlight-compatible streaming
# host on Linux is `custom.sysNixSunshine` (modules/systems/nixos/apps/
# sunshine.nix) — kept separate because Sunshine is a system service and
# Moonlight is a user-launched client.
#
# nixpkgs ships the Qt-based Moonlight client as `pkgs.moonlight-qt`.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/moonlight.nix ];
#   custom.appMoonlight.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appMoonlight;
in
{
  options.custom.appMoonlight.enable =
    lib.mkEnableOption "Moonlight game/desktop streaming client (nixpkgs moonlight-qt, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.moonlight-qt ];
  };
}
