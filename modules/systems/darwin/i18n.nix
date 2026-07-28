# Locale / i18n configuration (darwin)
#
# Two-knob model mirroring the NixOS sysNixI18n module:
#   userSettings.language       — UI language. macOS reads this from
#                                 NSGlobalDomain.AppleLanguages; the first
#                                 entry wins.
#   userSettings.regionalFormat — Dates, numbers, currency, paper sizes, etc.
#                                 macOS reads this from NSGlobalDomain.AppleLocale.
#                                 Defaults to `language` when unset.
#
# Both fields use BCP 47 dash form (e.g. "en-GB", "es-ES", "nl-NL"). The module
# also writes `environment.variables.LANG` to the matching POSIX locale so CLI
# tools running under the system shell pick up the same language.
#
# Implementation note: nix-darwin's `system.defaults.NSGlobalDomain` only
# exposes a curated subset of typed options. `AppleLanguages` and `AppleLocale`
# are not in that list, so we route them through `CustomUserPreferences`
# (a freeform `defaults write -g <key> <value>` passthrough).
#
# Note: AppleLanguages and AppleLocale are read at app launch. A language change
# requires logout/login (or app relaunch) to take effect across the running
# session. Falls back to "en-GB" when userSettings.language is unset.
#
# Usage:
#   imports = [ ../../../modules/systems/darwin/i18n.nix ];
#   custom.sysDarI18n.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  language = userSettings.language or (lib.warn
    "userSettings.language unset for host '${userSettings.hostname}'; defaulting to en-GB. Set it in infra-nix-config-private/hosts/${userSettings.hostname}/user-settings.nix."
    "en-GB");
  regionalFormat = userSettings.regionalFormat or language;
  toApple = t: builtins.replaceStrings [ "-" ] [ "_" ] t;
  toPosix = t: (builtins.replaceStrings [ "-" ] [ "_" ] t) + ".UTF-8";
in
{
  options = {
    custom.sysDarI18n.enable = lib.mkEnableOption "i18n / locale derived from userSettings.language and userSettings.regionalFormat";
  };

  config = lib.mkIf config.custom.sysDarI18n.enable {
    system.defaults.CustomUserPreferences.NSGlobalDomain = {
      AppleLanguages = [ language ];
      AppleLocale = toApple regionalFormat;
    };
    environment.variables.LANG = toPosix language;
  };
}
