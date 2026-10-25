# Unattended background auto-upgrade — stages new generations for next boot
#
# Periodically checks origin/main for verified commits and stages new system
# generations in the bootloader via `nixos-rebuild boot`. Active sessions,
# running applications, and GPU drivers are never interrupted; changes take
# effect cleanly upon the next reboot.
#
# Emits a timed desktop notification on successful staging (20s), and a sticky,
# non-expiring critical notification on failure that remains until dismissed.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/system/auto-upgrade.nix ];
#   custom.sysNixAutoUpgrade.enable = true;
#   custom.sysNixAutoUpgrade.dates = "04:00";
#   custom.sysNixAutoUpgrade.randomizedDelaySec = "30m";

{
  config,
  pkgs,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.sysNixAutoUpgrade;
  publicRepo = "/home/${userSettings.username}/${userSettings.repoPath}";
  workflowScript = "${publicRepo}/scripts/nix/switch-workflow.sh";
in
{
  options.custom.sysNixAutoUpgrade = {
    enable = lib.mkEnableOption "unattended background auto-upgrade staging system generations for next boot";

    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:00";
      description = "Systemd OnCalendar expression specifying when the background auto-upgrade runs.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "Randomized delay window to prevent multiple machines from pulling simultaneously.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.infra-nix-auto-upgrade = {
      description = "Infra Nix background auto-upgrade (stage for next boot)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [
        bash
        git
        gh
        gawk
        gnugrep
        gnused
        coreutils
        nix
        nixos-rebuild
        libnotify
        systemd
        util-linux
        sudo
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${workflowScript} auto-boot ${publicRepo} ${userSettings.hostname}";
        User = "root";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.timers.infra-nix-auto-upgrade = {
      description = "Timer for Infra Nix background auto-upgrade";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
      };
    };
  };
}
