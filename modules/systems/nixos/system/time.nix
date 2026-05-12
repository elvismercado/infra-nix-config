# Timezone configuration
#
# Sets time.timeZone from userSettings.timeZone so the host clock and
# log timestamps match the location configured in user-settings.nix.
# Falls back to "Etc/UTC" when userSettings.timeZone is unset (e.g. the
# public repo without a private overlay).
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
    time.timeZone = userSettings.timeZone or "Etc/UTC";
  };
}
