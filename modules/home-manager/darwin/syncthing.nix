# Syncthing — Darwin wrapper for the cross-platform syncthing core module.
#
# Binary is provided by the Homebrew cask `syncthing-app` (declared by the
# Option 3 app façade in `modules/apps/darwin/syncthing.nix`). The cask is
# a menubar GUI that owns the daemon and autostart — there is no
# `services.syncthing` analogue on darwin to wire here.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/syncthing.nix`. Hosts should normally not import
# this file directly.

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmSyncthing;
in
{
  imports = [ ../core/syncthing.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary + daemon + autostart; nothing to wire here.
  };
}
