# Thunderbird — Linux wrapper for the cross-platform thunderbird core module.
#
# Installs Thunderbird from nixpkgs via home-manager and creates a single
# default profile (accounts and identities are managed through Thunderbird's
# GUI, not declared here). Hunspell dictionaries are added so spellcheck
# works in the languages we care about.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/thunderbird.nix` (toggle `custom.appThunderbird.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/thunderbird.nix ];
#   custom.hmThunderbird.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmThunderbird;
in
{
  imports = [ ../core/thunderbird.nix ];

  config = lib.mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      profiles.default = {
        isDefault = true;
      };
    };

    home.packages = with pkgs; [
      hunspell
      hunspellDicts.en_GB-large
      hunspellDicts.nl_NL
      hunspellDicts.es_ES
      hunspellDicts.en_US-large
    ];
  };
}
