# Timezone configuration (darwin)
#
# Sets time.timeZone from userSettings.timeZone so macOS system clock,
# log timestamps, and scheduled jobs match the location configured in
# user-settings.nix. nix-darwin applies this via `systemsetup -settimezone`
# on activation, the same setting controlled by System Settings.
# Falls back to "Etc/UTC" when userSettings.timeZone is unset (e.g. the
# public repo without a private overlay).
#
# Usage:
#   imports = [ ../../../modules/systems/darwin/time.nix ];
#   custom.sysDarTimezone.enable = true;

{
  config,
  lib,
  userSettings, # from user-settings.nix
  ...
}:

{
  options = {
    custom.sysDarTimezone.enable = lib.mkEnableOption "timezone configuration from userSettings.timeZone";
  };

  config = lib.mkIf config.custom.sysDarTimezone.enable {
    time.timeZone = userSettings.timeZone or "Etc/UTC";
  };
}
