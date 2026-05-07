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

  # All JIN GUI apps are now wired through cross-layer façades under
  # modules/apps/linux/ — see hosts/JIN/configuration/default.nix
  # "Apps (cross-layer façades)". Nothing left to install raw here.
  home.packages = [ ];
}
