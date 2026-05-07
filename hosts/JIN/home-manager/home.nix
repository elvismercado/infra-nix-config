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

  # JIN-only packages — GUI utilities that don't belong on FENNEC and don't
  # warrant a façade yet.
  #
  # Lifted into Option 3 façades under modules/apps/ — see
  # hosts/JIN/configuration/default.nix "Apps (cross-layer façades)":
  #   signal-desktop, librewolf, libreoffice, rpi-imager, localsend,
  #   yubico-authenticator, brave, thunderbird, spotify, nextcloud,
  #   syncthing, handbrake, discord (vesktop).
  home.packages = with pkgs; [
    protonmail-bridge-gui # ProtonMail bridge
    insync # Google Drive, OneDrive, and Dropbox
  ];
}
