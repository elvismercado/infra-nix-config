# NixOS-specific layer over shared/packages.nix
#
# Imports shared/packages.nix (which provides git, gh, nano) and adds
# Linux-only base packages (libnotify for notify-send notifications).
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/packages.nix ];
#   custom.sysPackages.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../shared/packages.nix
  ];

  config = lib.mkIf config.custom.sysPackages.enable {
    environment.systemPackages = with pkgs; [
      libnotify
    ];
  };
}
