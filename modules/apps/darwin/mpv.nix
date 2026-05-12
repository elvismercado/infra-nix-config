# mpv — Darwin app façade
#
# Cross-layer module that owns the Homebrew formula `mpv` AND wires the
# matching home-manager wrapper under `custom.appMpv.enable`. Hosts
# should not also touch `homebrew.brews` for mpv or
# `custom.hmMpv.enable` directly.
#
# The formula ships an `mpv.app` bundle into `/Applications` alongside
# the `mpv` CLI in `/opt/homebrew/bin`. There is no working `mpv` cask
# on macOS today (`stolendata-mpv` is deprecated, fails Gatekeeper, and
# is disabled 2026-09-01); the formula is the only maintained route.
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
  options.custom.appMpv.enable = lib.mkEnableOption "mpv keyboard-driven video player (Homebrew formula mpv — ships mpv.app into /Applications)";

  config = lib.mkIf cfg.enable {
    homebrew.brews = [ "mpv" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/mpv.nix ];
      custom.hmMpv.enable = true;
    };
  };
}
