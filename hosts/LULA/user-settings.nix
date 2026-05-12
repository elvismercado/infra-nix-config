{
  username = "lula"; # username or name of the system user
  hostname = "LULA"; # as description or hostname
  system = "aarch64-darwin"; # 2026 MacBook Neo — Apple A-series silicon
  channel = "stable"; # "stable" or "unstable"
  # timeZone provided by the private overlay (nix-config-private); defaults to Etc/UTC.
  uid = 501; # required for users.knownUsers — find with `id -u <username>`
  repoPath = "git/nix-config"; # relative to $HOME
  desktopEnvironment = null; # macOS — DE managed by the OS
}
