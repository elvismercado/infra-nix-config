# Shutdown Disable Outputs — disable secondary monitors before shutdown/reboot
#
# Listens for logind's PrepareForShutdown D-Bus signal and immediately runs
# kscreen-doctor to disable specified outputs. This signal fires BEFORE the
# session teardown begins, so KWin is still fully functional and accepts
# configuration changes.
#
# Signal flow:
#   User clicks Reboot/Shutdown
#   → logind emits PrepareForShutdown(true) on system bus
#   → This daemon catches it, calls kscreen-doctor output.ID.disable
#   → logind proceeds with shutdown
#   → KWin receives shutdown notification, starts cleanup
#   → Plymouth starts shutdown splash (secondary monitor already disabled)
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/shutdown-disable-outputs.nix ];
#   custom.hmShutdownDisableOutputs.enable = true;
#   custom.hmShutdownDisableOutputs.connectors = [ "DP-2" ];

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmShutdownDisableOutputs;

  daemonScript = pkgs.writeShellApplication {
    name = "shutdown-disable-outputs";
    runtimeInputs = [
      pkgs.kdePackages.libkscreen
      pkgs.glib # gdbus
      pkgs.gnused
      pkgs.gawk
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      log() {
        echo "[shutdown-disable-outputs] $*" >&2
      }

      CONNECTORS="${lib.concatStringsSep " " cfg.connectors}"

      # Get cleaned kscreen-doctor output (strip ANSI escape codes)
      get_kscreen_output() {
        local raw
        raw=$(kscreen-doctor --outputs 2>/dev/null) || { log "kscreen-doctor unavailable"; return 1; }
        # shellcheck disable=SC2001
        echo "$raw" | sed 's/\x1b\[[0-9;]*m//g'
      }

      # Look up the kscreen output ID for a given DRM connector name
      get_output_id() {
        local connector="$1"
        local cleaned
        cleaned=$(get_kscreen_output) || return 1
        echo "$cleaned" | awk -v conn="$connector" '/^Output:/ && $3 == conn { print $2 }'
      }

      # Disable all configured connectors via kscreen-doctor
      disable_outputs() {
        log "PrepareForShutdown received — disabling outputs"
        for connector in $CONNECTORS; do
          local oid
          oid=$(get_output_id "$connector")
          if [ -n "$oid" ]; then
            log "Disabling $connector (id=$oid)"
            kscreen-doctor "output.$oid.disable" || log "Warning: failed to disable $connector"
          else
            log "Warning: $connector not found, skipping"
          fi
        done
        log "Done disabling outputs"
      }

      log "Listening for PrepareForShutdown on system bus..."

      # Monitor logind for PrepareForShutdown(true)
      gdbus monitor --system \
        --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1 \
      | while IFS= read -r line; do
        if [[ "$line" == *"PrepareForShutdown"*"true"* ]]; then
          disable_outputs
          exit 0
        fi
      done
    '';
  };
in

{
  options = {
    custom.hmShutdownDisableOutputs.enable = lib.mkEnableOption "disable secondary monitors on session shutdown for clean Plymouth splash";

    custom.hmShutdownDisableOutputs.connectors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "DP-2" ];
      description = ''
        DRM connector names to disable before shutdown/reboot.
        Listens for logind's PrepareForShutdown D-Bus signal and runs
        kscreen-doctor to disable these outputs while KWin is still alive.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
          message = "custom.hmShutdownDisableOutputs requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
        }
        {
          assertion = cfg.connectors != [ ];
          message = "custom.hmShutdownDisableOutputs.connectors must be a non-empty list of DRM connector names (e.g. [ \"DP-2\" ]) when the module is enabled";
        }
      ];
    })

    (lib.mkIf (cfg.enable && cfg.connectors != [ ]) {
      systemd.user.services.shutdown-disable-outputs = {
        Unit = {
          Description = "Disable secondary monitors before shutdown/reboot splash";
          After = [ "plasma-kwin_wayland.service" ];
          BindsTo = [ "plasma-kwin_wayland.service" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${daemonScript}/bin/shutdown-disable-outputs";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    })
  ];
}
