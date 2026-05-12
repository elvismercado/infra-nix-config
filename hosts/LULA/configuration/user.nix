{
  pkgs,
  userSettings,
  ...
}:

{
  # nix.settings.trusted-users is set at the flake level for NixOS hosts (flake/nixos.nix).
  # On darwin, nix.enable = false (Determinate Nix manages nix.conf) — use
  # determinateNix.customSettings.trusted-users if needed.

  users.knownUsers = [ userSettings.username ];

  users.users.${userSettings.username} = {
    uid = userSettings.uid;
    description = userSettings.hostname;
    home = "/Users/${userSettings.username}";
    shell = pkgs.bashInteractive;
  };

  networking.hostName = userSettings.hostname;
  networking.computerName = userSettings.hostname;
  networking.localHostName = userSettings.hostname;
  networking.wakeOnLan.enable = true;

  system.defaults.smb.NetBIOSName = userSettings.hostname;
  system.defaults.smb.ServerDescription = userSettings.hostname;
}
