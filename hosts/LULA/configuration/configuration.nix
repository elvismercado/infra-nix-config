# Manage dotfiles and user packages

{ userSettings, ... }:

{
  nixpkgs.hostPlatform = userSettings.system;
  system.stateVersion = 6; # required
  system.primaryUser = userSettings.username; # required for homebrew.enable and other per-user options
  nix.enable = false; # using determinate installer

  # macOS auto-updates — Maria's laptop should stay current without manual
  # intervention. These keys live under the SoftwareUpdate domain and are
  # forwarded to /Library/Preferences/com.apple.SoftwareUpdate.plist by
  # nix-darwin's CustomUserPreferences.
  system.defaults.CustomUserPreferences."com.apple.SoftwareUpdate" = {
    AutomaticCheckEnabled = true; # check for updates daily
    AutomaticDownload = 1; # download in background
    CriticalUpdateInstall = 1; # install security updates automatically
    ConfigDataInstall = 1; # install system data files automatically
    AutomaticallyInstallMacOSUpdates = true; # install macOS updates automatically
  };
}
