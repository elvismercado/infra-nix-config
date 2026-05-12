# mpv — cross-platform core (Option 2 split)
#
# Defines THE option `custom.hmMpv.enable`. The OS-specific wrappers
# (`linux/mpv.nix`, `darwin/mpv.nix`) own binary delivery: nixpkgs on
# Linux via `programs.mpv.enable`, the Homebrew cask on darwin.
#
# Internal — do not import from hosts. Imported by `linux/mpv.nix` and
# `darwin/mpv.nix`. Hosts wire mpv through the Option 3 app façade
# `custom.appMpv.enable` instead.

{
  lib,
  ...
}:

{
  options = {
    custom.hmMpv.enable = lib.mkEnableOption "mpv lightweight keyboard-driven video player";
  };
}
