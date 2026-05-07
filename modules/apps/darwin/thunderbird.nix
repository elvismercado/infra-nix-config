# Thunderbird — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `thunderbird` AND wires the
# matching home-manager wrapper under `custom.appThunderbird.enable`. Hosts
# should not also touch `homebrew.casks` for thunderbird or
# `custom.hmThunderbird.enable` directly.
#
# The HM darwin wrapper does NOT enable `programs.thunderbird` because that
# module's `package` is non-nullable and is dereferenced in several places
# (see `modules/home-manager/darwin/thunderbird.nix` for the full
# explanation). It only installs hunspell dictionaries — the cask binary
# auto-creates its profile under `~/Library/Thunderbird/Profiles/` on first
# launch, and accounts are configured through Thunderbird's GUI.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/thunderbird.nix ];
#   custom.appThunderbird.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appThunderbird;
in
{
  options.custom.appThunderbird.enable =
    lib.mkEnableOption "Thunderbird email client (Homebrew cask + hunspell dictionaries; install-only on HM side)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "thunderbird" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/thunderbird.nix ];
      custom.hmThunderbird.enable = true;
    };
  };
}
