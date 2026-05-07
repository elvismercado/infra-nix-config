# Syncthing — unified cross-platform module (Linux + macOS)
#
# Single Option 1 module: both NixOS and nix-darwin hosts get the daemon
# from `pkgs.syncthing` via home-manager's `services.syncthing`, which
# manages a systemd user service on Linux and a per-user LaunchAgent on
# darwin (see upstream HM `modules/services/syncthing.nix`,
# `launchd.agents.syncthing`).
#
# Cross-host policy (identical on every host):
#
#   - Auto-start at login                — systemd / launchd as appropriate.
#   - No anonymous usage telemetry       — settings.options.urAccepted = -1.
#   - No daemon self-upgrade             — settings.options.autoUpgradeIntervalH = 0;
#                                          nix owns the binary (channel-driven).
#   - No auto-created `~/Sync` folder    — relies on HM's `merge-syncthing-config`
#                                          pre-seeding `config.xml` from
#                                          `services.syncthing.settings` before the
#                                          daemon's first launch. Syncthing v2.0
#                                          removed the `--no-default-folder` CLI
#                                          flag (passing it now exits with code 80
#                                          and launchd/systemd throttle the unit);
#                                          since we manage folders per-host via
#                                          the Web UI and `settings.folders` stays
#                                          empty, the merged config has no folders
#                                          and the daemon won't fabricate "Default"
#                                          on a fresh install either.
#   - Web UI desktop shortcut            — clickable launcher for http://127.0.0.1:8384
#                                          via the cross-platform web-shortcuts helper.
#
# The ONLY OS branch is the Linux KDE system tray icon: upstream HM puts an
# `assertPlatform "...tray" pkgs lib.platforms.linux` on
# `services.syncthing.tray.enable`, so it cannot be enabled on darwin. We
# gate it on `userSettings.system` (NOT `pkgs.stdenv.hostPlatform`) because
# the same flag also picks the matching `web-shortcuts` renderer at
# `imports`-time — referencing `pkgs` from `imports` triggers an HM
# infinite recursion (it forces `config` to be evaluated to provide
# `_module.args.pkgs`, but `config` depends on `imports`). `userSettings`
# arrives via `extraSpecialArgs` and is available before `config`.
# macOS users use the Web UI shortcut as the entry point (no menubar icon
# — accepted trade-off; see `.archive/syncthing-2026-05-08/` for the
# previous cask-based setup).
#
# The matching `web-shortcuts.nix` wrapper is selected per OS so that the
# right renderer (`.desktop` on Linux, `.webloc` on darwin) is in scope.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/{linux,darwin}/syncthing.nix` (toggle
# `custom.appSyncthing.enable`). Hosts should normally not import this
# file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/all/syncthing.nix ];
#   custom.hmSyncthing.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmSyncthing;
  # Branch on userSettings.system (an extraSpecialArg) instead of
  # pkgs.stdenv.hostPlatform — referencing `pkgs` from `imports` would
  # require `config` (via `_module.args.pkgs`), which triggers an HM
  # infinite recursion. `userSettings` is available before `config`.
  isLinux = lib.hasSuffix "linux" userSettings.system;
in
{
  imports = [
    # Pick the matching web-shortcuts renderer for this host's OS.
    (if isLinux then ../linux/web-shortcuts.nix else ../darwin/web-shortcuts.nix)
  ];

  options.custom.hmSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (services.syncthing on both Linux and macOS)";

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      tray.enable = isLinux; # upstream HM gates this to platforms.linux
      overrideDevices = false; # devices added via the Web UI persist; must be removed manually
      overrideFolders = false; # folders added via the Web UI persist; must be removed manually
      # NB: do NOT add `--no-default-folder` to extraOptions — syncthing v2.0
      # removed the flag and rejects it with exit code 80 (launchd/systemd then
      # throttle the unit and the daemon never opens 8384). Default-folder
      # suppression on fresh installs is handled by HM's `merge-syncthing-config`
      # pre-seeding `config.xml` from `settings` (folders stay empty here).
      settings.options = {
        urAccepted = -1; # opt out of anonymous usage reporting (-1 = declined)
        localAnnounceEnabled = true;
        autoUpgradeIntervalH = 0; # disable daemon self-upgrade — nix owns the binary; channel-driven updates only
      };
    };

    # Clickable ~/Desktop launcher for the Web UI (renders .desktop on
    # Linux, .webloc on darwin).
    custom.hmWebShortcuts.enable = true;
    custom.hmWebShortcuts.entries.syncthing = {
      name = "Syncthing Web UI";
      url = "http://127.0.0.1:8384";
      comment = "Syncthing web interface";
      icon = "syncthing"; # Linux only — provided by pkgs.syncthing; falls back to default if missing
    };
  };
}
