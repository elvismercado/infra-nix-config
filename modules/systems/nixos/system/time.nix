# Timezone configuration
#
# Sets time.timeZone from userSettings.timeZone so the host clock and
# log timestamps match the location configured in user-settings.nix.
# Falls back to "Europe/London" when userSettings.timeZone is unset and
# emits a build-time warning naming the host and the file to edit.
# London is a placeholder, chosen to match the darwin module so behaviour
# is identical across OSes when the overlay is missing.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/system/time.nix ];
#   custom.sysNixTimezone.enable = true;

{
  config,
  lib,
  userSettings, # from user-settings.nix
  ...
}:

{
  options = {
    custom.sysNixTimezone.enable = lib.mkEnableOption "timezone configuration from userSettings.timeZone";
  };

  config = lib.mkIf config.custom.sysNixTimezone.enable {
    time.timeZone =
      userSettings.timeZone or (lib.warn
        "userSettings.timeZone unset for host '${userSettings.hostname}'; defaulting to Europe/London. Set it in nix-config-private/hosts/${userSettings.hostname}/user-settings.nix."
        "Europe/London");
  };
}
