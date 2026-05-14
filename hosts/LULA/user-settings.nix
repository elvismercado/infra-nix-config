{
  username = "lula"; # username or name of the system user
  hostname = "LULA"; # as description or hostname
  system = "x86_64-linux"; # Lenovo ThinkPad T14 Gen 2 — Intel i5-1135G7 (Tiger Lake)
  channel = "stable"; # "stable" or "unstable"
  # timeZone provided by the private overlay (nix-config-private); defaults to Etc/UTC.
  # uid = 501 is the macOS-era value, kept until Round 2 flips this host to NixOS.
  # The NixOS install will create the user with uid 1000 — update this then.
  uid = 501; # required for users.knownUsers — find with `id -u <username>`
  repoPath = "git/nix-config"; # relative to $HOME
  desktopEnvironment = "kde-plasma"; # planned: KDE Plasma + SDDM (matches JIN/FENNEC)
}
