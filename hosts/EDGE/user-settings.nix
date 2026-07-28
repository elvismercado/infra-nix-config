{
  username = "elvis"; # username or name of the system user
  hostname = "EDGE"; # as description or hostname
  system = "x86_64-darwin"; # 2018 Intel MacBook Pro
  channel = "stable"; # "stable" or "unstable"
  # timeZone provided by the private overlay (infra-nix-config-private); defaults to Etc/UTC.
  uid = 501; # required for users.knownUsers — find with `id -u <username>`
  repoPath = "git/infra-nix-config"; # relative to $HOME
  desktopEnvironment = null; # macOS — DE managed by the OS
}
