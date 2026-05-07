# Syncthing — shared cross-platform core
#
# Declares the `custom.hmSyncthing.enable` toggle. Wrappers add per-OS config:
#
#   - Linux wrapper:  enables `services.syncthing` with the system tray,
#                     non-overriding device/folder semantics, and opt-out
#                     anonymous usage telemetry.
#   - Darwin wrapper: empty config — the Homebrew cask `syncthing-app` is
#                     the menubar GUI and owns the daemon + autostart.
#
# Internal — do not import from hosts. Imported by `linux/syncthing.nix` and
# `darwin/syncthing.nix`. In normal use, hosts wire Syncthing through the
# Option 3 app façade `modules/apps/{linux,darwin}/syncthing.nix`.

{ lib, ... }:

{
  options.custom.hmSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (Linux: services.syncthing + tray; Darwin: Homebrew cask)";
}
