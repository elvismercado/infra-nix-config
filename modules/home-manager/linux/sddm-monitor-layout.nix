# SDDM monitor layout — home-manager API
# https://wiki.archlinux.org/title/SDDM#Match_Plasma_display_configuration
#
# KDE Plasma only — renders KWin's `kwinoutputconfig.json` from one of the
# user's `custom.hmDisplayProfiles.profiles`, and exposes the resulting
# `/nix/store/...` path via `_renderedConfig`. The system-side module
# `custom.sysNixSddmMonitorLayout` consumes that path to install the
# file under `/var/lib/sddm/.config/`.
#
# This is a Nix-pure replacement for the previous design which scraped
# `~/.config/kwinoutputconfig.json` at activation time. The chosen
# profile becomes the canonical login layout regardless of physical
# topology at boot.
#
# Usage:
#   imports = [
#     ../../../modules/home-manager/linux/sddm-monitor-layout.nix
#   ];
#   custom.hmSddmMonitorLayout.enable = true;
#   custom.hmSddmMonitorLayout.profile = "m1-4k";
#   # Optional: render specific connectors as disabled in the SDDM copy
#   custom.hmSddmMonitorLayout.disabledOutputs = [ "DP-2" ];

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmSddmMonitorLayout;
  dpCfg = config.custom.hmDisplayProfiles;

  render = import ./_sddm-kwin-render.nix { inherit pkgs lib; };
in
{
  options.custom.hmSddmMonitorLayout = {
    enable = lib.mkEnableOption "SDDM login screen layout matching a chosen display profile (KDE Plasma only)";

    profile = lib.mkOption {
      type = lib.types.str;
      example = "m1-4k";
      description = ''
        Name of the profile from `custom.hmDisplayProfiles.profiles` to
        use as the canonical SDDM login layout. The chosen profile's
        outputs, positions, scale, and rotation are rendered verbatim
        into `kwinoutputconfig.json` for the SDDM Wayland greeter.
      '';
    };

    disabledOutputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "DP-2" ];
      description = ''
        DRM connector names to render with `enabled = false` in the
        SDDM copy of `kwinoutputconfig.json`. The user's desktop session
        is unaffected (it uses its own KWin config).
      '';
    };

    _renderedConfig = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
      description = "Store path of the rendered kwinoutputconfig.json (consumed by sysNixSddmMonitorLayout).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmSddmMonitorLayout requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
      {
        assertion = dpCfg.profiles ? ${cfg.profile};
        message = ''
          custom.hmSddmMonitorLayout.profile = "${cfg.profile}" but no such profile
          exists in custom.hmDisplayProfiles.profiles. Available: ${
            lib.concatStringsSep ", " (lib.attrNames dpCfg.profiles)
          }
        '';
      }
      {
        assertion =
          let
            validConnectors = lib.attrNames (dpCfg.profiles.${cfg.profile}.outputs or { });
            invalid = lib.filter (c: !(builtins.elem c validConnectors)) cfg.disabledOutputs;
          in
          dpCfg.profiles ? ${cfg.profile} -> invalid == [ ];
        message = ''
          custom.hmSddmMonitorLayout.disabledOutputs contains connectors not present
          in profile "${cfg.profile}". Profile outputs: ${
            lib.concatStringsSep ", " (lib.attrNames (dpCfg.profiles.${cfg.profile}.outputs or { }))
          }
        '';
      }
    ];

    custom.hmSddmMonitorLayout._renderedConfig = render {
      profile = dpCfg.profiles.${cfg.profile};
      inherit (cfg) disabledOutputs;
    };
  };
}
