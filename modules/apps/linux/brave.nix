# Brave browser — Linux app façade
#
# Cross-layer module that wires Brave under `custom.appBrave.enable`. On
# Linux the binary comes from nixpkgs via home-manager (no system-layer cask
# needed), so this façade is a thin forwarder: it pulls the matching HM
# wrapper into HM scope and flips its enable toggle.
#
# Hosts should not also touch `custom.hmBrave.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/brave.nix ];
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
  imports = [ ../../systems/nixos/brave-policies.nix ];

  options.custom.appBrave.enable = lib.mkEnableOption "Brave browser (nixpkgs binary + KDE Plasma integration + managed policies)";

  config = lib.mkIf cfg.enable {
    custom.sysBravePolicies.enable = true;

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/brave.nix ];
      custom.hmBrave.enable = true;
    };
  };
}
