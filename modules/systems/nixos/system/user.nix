# Standard NixOS user account
#
# Creates the primary user from `userSettings` (username, uid, hostname) with
# the default group set used across NixOS hosts (networkmanager, wheel, video,
# render). Hosts can append additional groups via `extraGroups`. Also sets
# `users.mutableUsers`, the default user shell to bash, the system hostname,
# and enables NetworkManager (paired with the `networkmanager` group).
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/system/user.nix ];
#   custom.sysNixUser.enable = true;
#   # optional: custom.sysNixUser.extraGroups = [ "docker" ];

{
  config,
  pkgs,
  lib,
  userSettings,
  ...
}:

{
  options = {
    custom.sysNixUser.enable = lib.mkEnableOption "standard NixOS user account from userSettings (with NetworkManager and default groups)";

    custom.sysNixUser.extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional groups to append to the user's extraGroups (on top of the defaults).";
    };
  };

  config = lib.mkIf config.custom.sysNixUser.enable {
    users.mutableUsers = true;

    users.defaultUserShell = pkgs.bash;

    users.users.${userSettings.username} = {
      uid = userSettings.uid;
      isNormalUser = true;
      description = userSettings.hostname;
      initialPassword = userSettings.username;
      useDefaultShell = true;

      extraGroups = [
        "networkmanager" # Wi-Fi and network management
        "wheel" # sudo access
        "video" # GPU and display device access
        "render" # GPU rendering (e.g. Vulkan, OpenCL)
      ]
      ++ config.custom.sysNixUser.extraGroups;
    };

    networking.hostName = userSettings.hostname;
    networking.networkmanager.enable = true;
  };
}
