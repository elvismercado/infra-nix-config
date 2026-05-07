# Syncthing — shared cross-platform core
#
# Declares the `custom.hmSyncthing.enable` toggle. Wrappers add per-OS config
# but apply a shared policy across all hosts:
#
#   - Auto-start at login (Linux: systemd user service via services.syncthing;
#     Darwin: cask wrapper's StartAtLogin plist key).
#   - No in-app auto-update (Linux: settings.options.autoUpgradeIntervalH = 0,
#     daemon self-upgrade off because nix owns the binary; Darwin:
#     SUEnableAutomaticChecks = 0, brew handles wrapper updates).
#   - No anonymous usage telemetry (Linux: settings.options.urAccepted = -1;
#     Darwin: SUSendProfileInfo = 0).
#   - No auto-created ~/Sync "Default" folder on first launch (Linux: daemon
#     CLI flag --no-default-folder via services.syncthing.extraFlags;
#     Darwin: same flag passed via the wrapper's Arguments plist key).
#
# Wrapper specifics:
#
#   - Linux wrapper:  enables `services.syncthing` with the system tray and
#                     non-overriding device/folder semantics (devices and
#                     folders added via the Web UI persist across rebuilds).
#   - Darwin wrapper: empty config — the Homebrew cask `syncthing-app` is
#                     the menubar GUI and owns the daemon + autostart;
#                     wrapper-app preferences are pinned in the darwin
#                     façade via NSDefaults.
#
# Internal — do not import from hosts. Imported by `linux/syncthing.nix` and
# `darwin/syncthing.nix`. In normal use, hosts wire Syncthing through the
# Option 3 app façade `modules/apps/{linux,darwin}/syncthing.nix`.

{ lib, ... }:

{
  options.custom.hmSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (Linux: services.syncthing + tray; Darwin: Homebrew cask)";
}
