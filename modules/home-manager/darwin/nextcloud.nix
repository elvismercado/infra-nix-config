# Nextcloud — Darwin wrapper for the cross-platform nextcloud core module.
#
# Binary is provided by the Homebrew cask `nextcloud` (declared by the
# Option 3 app façade in `modules/apps/darwin/nextcloud.nix`). This wrapper
# has no config to add — Nextcloud account configuration is GUI-only.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/nextcloud.nix`. Hosts should normally not import
# this file directly.

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmNextcloud;
in
{
  imports = [ ../core/nextcloud.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary; nothing to wire here yet.
  };
}
