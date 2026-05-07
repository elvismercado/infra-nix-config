# HandBrake — Darwin wrapper for the cross-platform handbrake core module.
#
# Binary is provided by the Homebrew cask `handbrake-app` (declared by the
# Option 3 app façade in `modules/apps/darwin/handbrake.nix`). This wrapper
# has no config to add.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/handbrake.nix`. Hosts should normally not import
# this file directly.

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmHandbrake;
in
{
  imports = [ ../core/handbrake.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary; nothing to wire here yet.
  };
}
