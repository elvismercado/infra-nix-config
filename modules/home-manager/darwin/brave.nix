# Brave browser — Darwin wrapper for the cross-platform brave core module.
#
# Binary is provided by the Homebrew cask `brave-browser` (declared by the
# Option 3 app façade in `modules/apps/darwin/brave.nix`). This wrapper has
# no config to add — there is no KDE Plasma on macOS, so no native messaging
# hosts to register, and Brave settings are managed through its own sync /
# GUI rather than a home-manager module.
#
# The file exists for OS-symmetric host wiring: every host enables Brave via
# `custom.appBrave.enable`, regardless of OS. If darwin-specific Brave config
# ever becomes useful (e.g., `home.file` writes for managed policies), add it
# here inside the `lib.mkIf cfg.enable` block.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/brave.nix`. Hosts should normally not import this
# file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/darwin/brave.nix ];
#   custom.hmBrave.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmBrave;
in
{
  imports = [ ../core/brave.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary; nothing to wire here yet.
  };
}
