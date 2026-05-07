# Brave browser — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `brave-browser` AND wires
# the matching home-manager wrapper under `custom.appBrave.enable`. Hosts
# should not also touch `homebrew.casks` for brave or `custom.hmBrave.enable`
# directly.
#
# The HM darwin wrapper currently has no per-OS config (no Plasma on macOS,
# no managed Brave settings via HM); the wrapper still gets pulled in for
# OS-symmetric host wiring and as a future hook for darwin-specific tweaks.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/brave.nix ];
#   custom.appBrave.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appBrave;
in
{
  options.custom.appBrave.enable = lib.mkEnableOption "Brave browser (Homebrew cask + HM wrapper)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "brave-browser" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/brave.nix ];
      custom.hmBrave.enable = true;
    };
  };
}
