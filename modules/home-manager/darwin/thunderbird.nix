# Thunderbird — Darwin wrapper for the cross-platform thunderbird core module.
#
# Binary is provided by the Homebrew cask `thunderbird` (declared by the
# Option 3 app façade in `modules/apps/darwin/thunderbird.nix`). This wrapper
# does NOT enable `programs.thunderbird` because that HM module's `package`
# is typed non-nullable via `mkPackageOption pkgs "thunderbird"` and it
# dereferences `cfg.package` for `home.packages` and native messaging host
# registration — it cannot be used in cask-only mode.
#
# We could mirror the VS Code pattern (bypass `programs.thunderbird` entirely
# and reproduce profiles.ini / user.js generation via `home.file`), but the
# current usage doesn't manage any settings or accounts declaratively —
# Thunderbird auto-creates its profile under
# `~/Library/Thunderbird/Profiles/<random>.default` on first launch, and
# accounts are configured through the GUI. So this wrapper installs only the
# hunspell dictionaries (mirroring the Linux wrapper's package list) and lets
# the cask binary handle the rest.
#
# If declarative settings ever become useful on darwin, add a
# `custom.hmThunderbird.settings` option to `core/thunderbird.nix` and
# replicate the relevant subset of `programs.thunderbird`'s file writes via
# `home.file."Library/Thunderbird/profiles.ini"` etc. — the cask binary reads
# the same paths the HM module would write.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/thunderbird.nix`. Hosts should normally not import
# this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/darwin/thunderbird.nix ];
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
    home.packages = with pkgs; [
      hunspell
      hunspellDicts.en_GB-large
      hunspellDicts.nl_NL
      hunspellDicts.es_ES
      hunspellDicts.en_US-large
    ];
  };
}
