# HandBrake — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `handbrake-app` AND wires
# the matching home-manager wrapper under `custom.appHandbrake.enable`.
# Hosts should not also touch `homebrew.casks` for handbrake-app or
# `custom.hmHandbrake.enable` directly.
#
# The HM darwin wrapper currently has no per-OS config; the wrapper is
# pulled in for OS-symmetric host wiring and as a future hook.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/handbrake.nix ];
#   custom.appHandbrake.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appHandbrake;
in
{
  options.custom.appHandbrake.enable =
    lib.mkEnableOption "HandBrake video transcoder GUI (Homebrew cask handbrake-app)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "handbrake-app" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/handbrake.nix ];
      custom.hmHandbrake.enable = true;
    };
  };
}
