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
  # yubioath-flutter were lifted into Option 3 install-only façades — they're
  # now wired in hosts/JIN/configuration/default.nix under "Apps (cross-layer
  # façades)". librewolf stays here for now until its settings-managed
  # façade lands.
  home.packages = with pkgs; [
    protonmail-bridge-gui # ProtonMail bridge
    insync # Google Drive, OneDrive, and Dropbox
    librewolf # Privacy-hardened Firefox fork (TODO: lift to façade)
    yubikey-manager # YubiKey CLI
  ];
}
