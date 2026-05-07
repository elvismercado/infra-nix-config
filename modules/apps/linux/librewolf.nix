# LibreWolf — Linux app façade
#
# Cross-layer module that wires LibreWolf under `custom.appLibrewolf.enable`.
# On Linux the binary comes from nixpkgs via home-manager, so this façade is
# a thin forwarder: it pulls the matching HM wrapper into HM scope and flips
# its enable toggle.
#
# Hosts should not also touch `custom.hmLibrewolf.enable` directly. Hosts
# that want to override settings can do so on the façade-injected HM scope:
#
#   custom.appLibrewolf.enable = true;
#   home-manager.users.<u>.custom.hmLibrewolf.settings = { ... };
#
# Usage:
#   imports = [ ../../../modules/apps/linux/librewolf.nix ];
#   custom.appLibrewolf.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appLibrewolf;
in
{
  options.custom.appLibrewolf.enable =
    lib.mkEnableOption "LibreWolf browser (nixpkgs binary + declarative HM settings)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/librewolf.nix ];
      custom.hmLibrewolf.enable = true;
    };
  };
}
