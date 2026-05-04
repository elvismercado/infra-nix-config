# SDDM Monitor Layout — deploy kwinoutputconfig.json to the SDDM user
# https://wiki.archlinux.org/title/SDDM#Match_Plasma_display_configuration
#
# KDE Plasma only — deploys KWin's output config to the SDDM Wayland
# greeter. Module asserts `userSettings.desktopEnvironment ==
# "kde-plasma"` when enabled.
#
# Copies your KDE Plasma monitor layout (positions, resolutions,
# rotations, primary display, scaling) to the SDDM user's config
# directory so the Wayland greeter (kwin_wayland) inherits the same
# layout on the login screen.
#
# The source file is auto-detected from the first user's home directory
# at ~/.config/kwinoutputconfig.json during system activation.
#
# Optionally, specific outputs can be disabled for the SDDM login screen
# only (e.g. to show the greeter on the primary monitor only). The
# user's desktop session is unaffected — KDE uses its own config.
#
# Usage:
#   imports = [
#     ../../../modules/systems/nixos/display_manager/sddm-monitor-layout.nix
#   ];
#   custom.sysNixSddmMonitorLayout.enable = true;
#
#   # Optional: disable secondary monitor on the login screen
#   custom.sysNixSddmMonitorLayout.disabledOutputs = [ "DP-2" ];

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.sysNixSddmMonitorLayout;
in
{
  options = {
    custom.sysNixSddmMonitorLayout.enable = lib.mkEnableOption "applies monitor layout to SDDM login screen (KDE Plasma only)";

    custom.sysNixSddmMonitorLayout.disabledOutputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "DP-2" ];
      description = ''
        DRM connector names to disable on the SDDM login screen.
        These outputs will be set to "enabled": false in the
        kwinoutputconfig.json deployed to the SDDM user, so the
        KWin Wayland greeter only renders on the remaining outputs.
        The user's desktop session is unaffected.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.sysNixSddmMonitorLayout requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
    ];

    # Deploy the kwin output config to the sddm user on every rebuild/activation.
    # This ensures the SDDM Wayland greeter (which uses kwin_wayland)
    # renders with the correct monitor layout.
    system.activationScripts.sddmMonitorLayout = {
      text =
        let
          disabledOutputs = config.custom.sysNixSddmMonitorLayout.disabledOutputs;
          jq = "${pkgs.jq}/bin/jq";

          # Build a jq filter that disables specified outputs in every setup.
          # For each disabled connector, find its outputIndex from the "outputs"
          # section, then set "enabled": false for matching entries in "setups".
          disableFilter = lib.concatMapStringsSep " | " (connector: ''
            (.[0].data | to_entries | map(select(.value.connectorName == "${connector}")) | .[0].key) as $idx |
            .[1].data |= map(.outputs |= map(if .outputIndex == $idx then .enabled = false else . end))
          '') disabledOutputs;
        in
        ''
          SDDM_CONFIG="/var/lib/sddm/.config"
          mkdir -p "$SDDM_CONFIG"

          # Auto-detect: copy from the first user's home directory if available
          for HOME_DIR in /home/*/; do
            if [ -f "$HOME_DIR.config/kwinoutputconfig.json" ]; then
              cp "$HOME_DIR.config/kwinoutputconfig.json" "$SDDM_CONFIG/kwinoutputconfig.json"
              break
            fi
          done

          ${lib.optionalString (disabledOutputs != [ ]) ''
            # Disable specified outputs for the SDDM greeter only
            if [ -f "$SDDM_CONFIG/kwinoutputconfig.json" ]; then
              ${jq} '${disableFilter}' "$SDDM_CONFIG/kwinoutputconfig.json" > "$SDDM_CONFIG/kwinoutputconfig.json.tmp" \
                && mv "$SDDM_CONFIG/kwinoutputconfig.json.tmp" "$SDDM_CONFIG/kwinoutputconfig.json"
            fi
          ''}

          if [ -f "$SDDM_CONFIG/kwinoutputconfig.json" ]; then
            chown sddm:sddm "$SDDM_CONFIG/kwinoutputconfig.json"
          fi
        '';
    };
  };
}
