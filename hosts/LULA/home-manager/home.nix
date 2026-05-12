{ userSettings, ... }:

{
  home.username = userSettings.username;
  home.homeDirectory = "/Users/${userSettings.username}";
  home.stateVersion = "25.11";
}
