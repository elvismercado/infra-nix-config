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
  home.packages = with pkgs; [
    protonmail-bridge-gui # ProtonMail bridge
    insync # Google Drive, OneDrive, and Dropbox
    signal-desktop # Secure messaging
    librewolf # Privacy-hardened Firefox fork
    libreoffice # Office suite
    rpi-imager # Raspberry Pi imaging utility
    localsend # Cross-platform AirDrop alternative
    yubikey-manager # YubiKey CLI
    yubioath-flutter # YubiKey Authenticator GUI
  ];
}
