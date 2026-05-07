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

  # JIN-only packages — tray apps + GUI utilities that don't belong on FENNEC.
  # Kept as raw home.packages (no module) until any of them grow declarative
  # config worth abstracting.
  #
  # signal-desktop / librewolf / libreoffice / rpi-imager / localsend /
  # yubioath-flutter / brave / thunderbird were lifted into Option 3 façades
  # under modules/apps/ — see hosts/JIN/configuration/default.nix "Apps
  # (cross-layer façades)" section.
  home.packages = with pkgs; [
    protonmail-bridge-gui # ProtonMail bridge
    insync # Google Drive, OneDrive, and Dropbox
    yubikey-manager # YubiKey CLI
  ];
}
