# Brave browser — Linux wrapper for the cross-platform brave core module.
#
# Installs Brave from nixpkgs via home-manager and (when the host's
# `userSettings.desktopEnvironment = "kde-plasma"`) registers
# `pkgs.kdePackages.plasma-browser-integration` as a native messaging host
# so KDE Plasma can talk to Brave (media controls, downloads, notifications).
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/brave.nix` (toggle `custom.appBrave.enable`). Hosts
# should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/brave.nix ];
#   custom.hmBrave.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmBrave;
in
{
  imports = [ ../core/brave.nix ];

  config = lib.mkIf cfg.enable {
    programs.brave = {
      enable = true;

      nativeMessagingHosts =
        lib.optionals ((userSettings.desktopEnvironment or null) == "kde-plasma")
          [ pkgs.kdePackages.plasma-browser-integration ];
    };
  };
}
