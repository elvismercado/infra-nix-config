{
  username = "fennec"; # username or name of the system user
  hostname = "FENNEC"; # as description or hostname
  system = "x86_64-linux";
  channel = "stable"; # "stable" or "unstable"
  # timeZone provided by the private overlay (infra-nix-config-private); defaults to Etc/UTC.
  uid = 1000; # UID for the system user — must match install script chown
  repoPath = "git/infra-nix-config"; # relative to $HOME
  desktopEnvironment = "kde-plasma"; # "kde-plasma", "cosmic", etc.
}
