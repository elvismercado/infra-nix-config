# Linux-only user packages not managed by a dedicated module
#
# GUI apps that use Homebrew casks on macOS belong here.
# Cross-platform CLI tools belong in all/base.nix instead.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/packages.nix ];
#   custom.hmLinuxPackages.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

{
  options = {
    custom.hmLinuxPackages.enable = lib.mkEnableOption "Linux-only Home Manager packages (LocalSend, Mullvad VPN client, etc.)";
  };

  config = lib.mkIf config.custom.hmLinuxPackages.enable {
    home.packages = with pkgs; [
      localsend
      mullvad-vpn # Client for Mullvad VPN
      moonlight-qt # Open source game streaming client

      cameractrls # Camera controls for Linux

      rpi-imager # Raspberry Pi Imaging Utility

      beeper # all chats in one app

      # stuff that should always be in the "systemtray"
      ferdium # browser for always on services
    ];
  };
}
