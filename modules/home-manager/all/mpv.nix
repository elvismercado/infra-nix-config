# mpv — lightweight video player
#
# Keyboard-driven media player with wide format support.
#
# Canonical Option 1 exemplar: a single `all/` module with identical wiring on every host.
# See [.github/instructions/cross-platform.instructions.md](../../../.github/instructions/cross-platform.instructions.md).
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/mpv.nix ];
#   custom.hmMpv.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.hmMpv.enable = lib.mkEnableOption "mpv lightweight keyboard-driven video player";
  };

  config = lib.mkIf config.custom.hmMpv.enable {
    programs.mpv.enable = true;
  };
}
