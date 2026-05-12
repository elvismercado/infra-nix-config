# macOS-only shell aliases
#
# Provides darwin-rebuild switch/build aliases
# (`switch`, `switchverbose`, `switchbuild`, `switchtest`, `switchhealth`, `switchhelp`).
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/aliases.nix ];
#   custom.hmDarwinAliases.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

{
  options = {
    custom.hmDarwinAliases.enable = lib.mkEnableOption "macOS shell aliases (darwin-rebuild switch/build helpers)";
  };

  config = lib.mkIf config.custom.hmDarwinAliases.enable {
    home.shellAliases = {
      switch = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && sudo darwin-rebuild switch --flake path:.#${userSettings.hostname}";
      switchverbose = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && sudo darwin-rebuild switch --flake path:.#${userSettings.hostname} --show-trace --print-build-logs -L -v";
      switchbuild = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && darwin-rebuild build --flake path:.#${userSettings.hostname}";
      switchtest = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && darwin-rebuild check --flake path:.#${userSettings.hostname}";
      switchhealth = "{ echo '=== System errors (last 1h) ==='; log show --predicate 'eventType == logEvent && messageType == error' --last 1h --style compact 2>/dev/null | tail -50; echo '=== Disk usage ==='; df -h / /System/Volumes/Data; echo '=== Nix store size ==='; du -sh /nix/store 2>/dev/null; echo '=== Homebrew status ==='; brew doctor 2>&1 | head -20; } > /tmp/health.txt 2>&1 && echo \"Saved to /tmp/health.txt ($(wc -l < /tmp/health.txt) lines)\"";
      switchhelp = "echo -e '\n  switch        — Rebuild and activate system config\n                  sudo darwin-rebuild switch --flake path:.#${userSettings.hostname}\n  switchverbose — Same as switch, with full build logs + eval trace\n                  sudo darwin-rebuild switch --flake path:.#${userSettings.hostname} --show-trace --print-build-logs -L -v\n  switchbuild   — Build config without activating\n                  darwin-rebuild build --flake path:.#${userSettings.hostname}\n  switchtest    — Test build (check)\n                  darwin-rebuild check --flake path:.#${userSettings.hostname}\n  switchcheck   — Validate flake\n                  nix flake check\n  switchupdate  — Update flake inputs\n                  nix flake update\n  switchhealth  — Save system health report to /tmp/health.txt\n  switchcd      — cd to nix-config repo\n  switchhelp    — Show this help\n'";
    };
  };
}
