# mpv — Darwin wrapper for the cross-platform mpv core module.
#
# Binary is provided by the Homebrew cask `mpv` (declared by the Option 3
# app façade in `modules/apps/darwin/mpv.nix`). This wrapper has no config
# to add today; it exists for OS-symmetric host wiring and as a future
# hook for declarative `~/.config/mpv/mpv.conf` writing.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/mpv.nix`. Hosts should normally not import this
# file directly.

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmMpv;
in
{
  imports = [ ../core/mpv.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary; nothing to wire here yet.
  };
}
