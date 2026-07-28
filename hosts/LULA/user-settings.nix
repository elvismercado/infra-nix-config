{
  username = "lula"; # username or name of the system user
  hostname = "LULA"; # as description or hostname
  system = "x86_64-linux"; # Lenovo ThinkPad T14 Gen 2 — Intel i5-1135G7 (Tiger Lake)
  channel = "stable"; # "stable" or "unstable"
  # timeZone / language / regionalFormat provided by the private overlay (infra-nix-config-private).
  uid = 1000; # default NixOS uid for the first normal user — verify with `id -u lula`
  repoPath = "git/infra-nix-config"; # relative to $HOME
  desktopEnvironment = "kde-plasma"; # KDE Plasma + SDDM (matches JIN/FENNEC)
}
