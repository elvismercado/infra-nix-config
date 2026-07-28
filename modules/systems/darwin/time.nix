# Timezone configuration (darwin)
#
# Sets time.timeZone from userSettings.timeZone so macOS system clock,
# log timestamps, and scheduled jobs match the location configured in
# user-settings.nix. nix-darwin applies this via `systemsetup -settimezone`
# on activation, the same setting controlled by System Settings.
#
# Falls back to "Europe/London" when userSettings.timeZone is unset and
# emits a build-time warning naming the host and the file to edit. London
# is a placeholder — it's a real geographic tz that exists in macOS's
# `systemsetup -listtimezones` and on every Linux glibc, so the fallback
# always activates cleanly. "UTC" / "Etc/UTC" were tried first but macOS
# rejects both forms.
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
    time.timeZone =
      userSettings.timeZone or (lib.warn
        "userSettings.timeZone unset for host '${userSettings.hostname}'; defaulting to Europe/London. Set it in infra-nix-config-private/hosts/${userSettings.hostname}/user-settings.nix."
        "Europe/London");
  };
}
