# Host-specific Home Manager config for JIN

{
  pkgs,
  userSettings,
  ...
}:

{
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";
  home.stateVersion = "25.11";

  # JIN-only packages — tray apps that don't belong on FENNEC.
  home.packages = with pkgs; [
    protonmail-bridge-gui # ProtonMail bridge
    insync # Google Drive, OneDrive, and Dropbox
  ];
}
