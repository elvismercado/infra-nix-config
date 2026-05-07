# Syncthing — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `syncthing-app` AND wires
# the matching home-manager wrapper under `custom.appSyncthing.enable`. The
# cask is the menubar GUI and owns the daemon + autostart on darwin (there
# is no `services.syncthing` analogue on macOS in nix-darwin/HM).
#
# Wrapper-app preferences are pinned via NSDefaults on the wrapper's
# `com.github.xor-gate.syncthing-macosx` domain so a fresh install matches
# the policy used on Linux:
#   - StartAtLogin            = 1   (auto-start menubar app at login)
#   - SUEnableAutomaticChecks = 0   (no in-app Sparkle update — brew handles it)
#   - SUSendProfileInfo       = 0   (opt out of Sparkle telemetry)
#   - Arguments               = "--no-default-folder" (skip auto-creating ~/Sync)
#
# These keys are wrapper-owned; the syncthing daemon never rewrites this
# plist, so there's no tug-of-war. Other plist keys are deliberately NOT
# declared:
#   - ApiKey                       (SECRET, per-host, daemon-generated)
#   - Executable, URI              (auto-detected by the wrapper; pinning is fragile)
#   - NSWindow Frame *, SU* state  (window position / Sparkle state, written by the app)
#
# Hosts should not also touch `homebrew.casks` for syncthing-app or
# `custom.hmSyncthing.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/syncthing.nix ];
#   custom.appSyncthing.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appSyncthing;
in
{
  options.custom.appSyncthing.enable = lib.mkEnableOption "Syncthing continuous file synchronisation (Homebrew cask syncthing-app)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "syncthing-app" ];

    # Pin wrapper-app preferences — see header for rationale and exclusions.
    system.defaults.CustomUserPreferences."com.github.xor-gate.syncthing-macosx" = {
      StartAtLogin = 1;
      SUEnableAutomaticChecks = 0;
      SUSendProfileInfo = 0;
      Arguments = "--no-default-folder";
    };

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/syncthing.nix ];
      custom.hmSyncthing.enable = true;
    };
  };
}
