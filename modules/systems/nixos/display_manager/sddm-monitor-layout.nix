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
# At activation time the script patches each output's `edidHash` from
# the live monitor EDID under `/sys/class/drm/card*-<connector>/edid`
# (md5). KWin matches outputs by `connectorName + edidHash`; without
# this patch KWin would treat our rendered entries as different outputs
# than the physical ones, ignore our setup, and append its own learned
# topology to the file on every greeter session. Missing EDID (monitor
# unplugged at rebuild) → hash stays empty → KWin falls back to
# connectorName-only matching for that connector.
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
  pkgs,
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
    #
    # After cp, patch each output's `edidHash` from the live monitor
    # EDID at /sys/class/drm/card*-<connector>/edid (md5). KWin matches
    # outputs by `connectorName + edidHash`; without the hash it would
    # treat our entry as a different output, ignore our setup, and
    # append its own learned topology. Missing EDID (monitor unplugged)
    # → leave hash empty → KWin falls back to connectorName matching.
    system.activationScripts.sddmMonitorLayout = {
      text = ''
        export PATH="${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.jq
          ]
        }:$PATH"

        SDDM_CONFIG="/var/lib/sddm/.config"
        mkdir -p "$SDDM_CONFIG"

        TMP=$(mktemp)
        cp ${hmSddm._renderedConfig or "/dev/null"} "$TMP"

        # Patch edidHash for each connector from /sys EDID (md5).
        connectors=$(jq -r '.[0].data[].connectorName' "$TMP")
        for connector in $connectors; do
          edid_path=$(echo /sys/class/drm/card*-"$connector"/edid)
          [ -f "$edid_path" ] || continue
          hash=$(md5sum "$edid_path" 2>/dev/null | cut -d' ' -f1)
          [ -z "$hash" ] && continue
          jq --arg c "$connector" --arg h "$hash" \
            '.[0].data |= map(if .connectorName == $c then .edidHash = $h else . end)' \
            "$TMP" > "$TMP.new" && mv "$TMP.new" "$TMP"
        done

        mv "$TMP" "$SDDM_CONFIG/kwinoutputconfig.json"
        chown sddm:sddm "$SDDM_CONFIG/kwinoutputconfig.json"
      '';
    };
  };
}
