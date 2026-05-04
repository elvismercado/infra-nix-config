# SDDM Monitor Layout — install rendered kwinoutputconfig.json for SDDM
# https://wiki.archlinux.org/title/SDDM#Match_Plasma_display_configuration
#
# KDE Plasma only — copies the home-manager-rendered
# `kwinoutputconfig.json` (produced by `custom.hmSddmMonitorLayout`)
# into `/var/lib/sddm/.config/` on every system activation, so the SDDM
# Wayland greeter renders with the chosen canonical layout.
#
# Source is a deterministic `/nix/store/...` path produced at evaluation
# time from `custom.hmDisplayProfiles.profiles` — not scraped from
# runtime KWin state. The login layout is therefore stable regardless
# of which physical topology is active at the time of `nixos-rebuild`.
#
# Companion to `modules/home-manager/linux/sddm-monitor-layout.nix`,
# which exposes the profile selection and disabledOutputs API.
#
# Usage:
#   imports = [
#     ../../../modules/systems/nixos/display_manager/sddm-monitor-layout.nix
#   ];
#   custom.sysNixSddmMonitorLayout.enable = true;
#   # Optional override: which user's hm config to read from (defaults to userSettings.username)
#   # custom.sysNixSddmMonitorLayout.sourceUser = "elvis";

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.sysNixSddmMonitorLayout;
  hmUserCfg = config.home-manager.users.${cfg.sourceUser} or { };
  hmSddm = hmUserCfg.custom.hmSddmMonitorLayout or { };
in
{
  options.custom.sysNixSddmMonitorLayout = {
    enable = lib.mkEnableOption "installs the home-manager-rendered SDDM monitor layout (KDE Plasma only)";

    sourceUser = lib.mkOption {
      type = lib.types.str;
      default = userSettings.username;
      description = ''
        Which home-manager user's `custom.hmSddmMonitorLayout` should
        provide the rendered `kwinoutputconfig.json`. Defaults to the
        primary user from `user-settings.nix`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.sysNixSddmMonitorLayout requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
      {
        assertion = (hmSddm.enable or false) == true;
        message = ''
          custom.sysNixSddmMonitorLayout.enable = true requires
          custom.hmSddmMonitorLayout.enable = true in user
          "${cfg.sourceUser}"'s home-manager config.
        '';
      }
    ];

    # Copy the rendered store path into SDDM's config dir on every
    # activation. The source path changes (new store hash) only when
    # the underlying profile or disabledOutputs change in Nix.
    system.activationScripts.sddmMonitorLayout = {
      text = ''
        SDDM_CONFIG="/var/lib/sddm/.config"
        mkdir -p "$SDDM_CONFIG"
        cp ${hmSddm._renderedConfig or "/dev/null"} "$SDDM_CONFIG/kwinoutputconfig.json"
        chown sddm:sddm "$SDDM_CONFIG/kwinoutputconfig.json"
      '';
    };
  };
}
