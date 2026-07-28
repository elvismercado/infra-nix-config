# Locale / i18n configuration
#
# Two-knob model:
#   userSettings.language       — UI language (LC_MESSAGES / LC_CTYPE / LC_COLLATE
#                                 and i18n.defaultLocale). BCP 47 dash form, e.g.
#                                 "en-GB", "es-ES", "nl-NL".
#   userSettings.regionalFormat — Dates, numbers, currency, paper, addresses
#                                 (LC_TIME / LC_MONETARY / LC_PAPER / ...).
#                                 Same BCP 47 dash form. Defaults to `language`
#                                 when unset.
#
# Both fields typically live in the private overlay (infra-nix-config-private). When
# absent (public repo standalone), both fall back to "en-GB".
#
# A four-locale pad (en_GB, nl_NL, es_ES, en_US) is generated unconditionally so
# ad-hoc `LANG=<other> cmd` works without rebuilding.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/system/i18n.nix ];
#   custom.sysNixI18n.enable = true;

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
  toPosix = t: (builtins.replaceStrings [ "-" ] [ "_" ] t) + ".UTF-8";
  uiLocale = toPosix language;
  fmtLocale = toPosix regionalFormat;
in
{
  options = {
    custom.sysNixI18n.enable = lib.mkEnableOption "i18n / locale derived from userSettings.language and userSettings.regionalFormat";
  };

  config = lib.mkIf config.custom.sysNixI18n.enable {
    i18n.defaultLocale = uiLocale;
    i18n.defaultCharset = "UTF-8";

    i18n.extraLocales = lib.unique [
      "${uiLocale}/UTF-8"
      "${fmtLocale}/UTF-8"
      "en_GB.UTF-8/UTF-8"
      "nl_NL.UTF-8/UTF-8"
      "es_ES.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8" # Supporting because its 'most defaulted to', 'most common', 'most assumed' etc.
    ];

    i18n.extraLocaleSettings = {
      # UI cluster — from userSettings.language
      LC_CTYPE = uiLocale; # Character classification and case conversion
      LC_MESSAGES = uiLocale; # UI language and system messages
      LC_COLLATE = uiLocale; # Sorting order

      # Regional cluster — from userSettings.regionalFormat
      LC_ADDRESS = fmtLocale; # Address formatting
      LC_IDENTIFICATION = fmtLocale; # Locale metadata
      LC_MEASUREMENT = fmtLocale; # Measurement units
      LC_MONETARY = fmtLocale; # Currency formatting
      LC_NAME = fmtLocale; # Personal name formatting
      LC_NUMERIC = fmtLocale; # Numeric formatting
      LC_PAPER = fmtLocale; # Paper size
      LC_TELEPHONE = fmtLocale; # Telephone number formatting
      LC_TIME = fmtLocale; # Date and time formats
    };
  };
}
