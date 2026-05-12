# mpv — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `mpv` AND wires the
# matching home-manager wrapper under `custom.appMpv.enable`. Hosts
# should not also touch `homebrew.casks` for mpv or
# `custom.hmMpv.enable` directly.
#
# The HM darwin wrapper currently has no per-OS config; the wrapper is
# pulled in for OS-symmetric host wiring and as a future hook.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/mpv.nix ];
#   custom.appMpv.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appMpv;
in
{
  options.custom.appMpv.enable = lib.mkEnableOption "mpv keyboard-driven video player (Homebrew cask mpv)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "mpv" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/mpv.nix ];
      custom.hmMpv.enable = true;
    };
  };
}
