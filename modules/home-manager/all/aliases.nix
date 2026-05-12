# Cross-platform shell aliases — nix workflow, diagnostics
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/aliases.nix ];
#   custom.hmAliases.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  # Wrap fun* toys in the host's idle inhibitor so the screen doesn't
  # blank and the system doesn't auto-suspend while they're running.
  # Released automatically when the toy exits (Ctrl-C, q, etc.).
  # Manual Sleep / `systemctl suspend` / shutdown still work.
  isLinux = lib.hasSuffix "linux" userSettings.system;
  funWrap =
    if isLinux then
      ''systemd-inhibit --what=idle:sleep --who=fun --why="terminal eye candy" -- ''
    else
      "caffeinate -dis ";
in

{
  options = {
    custom.hmAliases.enable = lib.mkEnableOption "cross-platform Home Manager shell aliases (nix workflow, diagnostics)";
  };

  config = lib.mkIf config.custom.hmAliases.enable {
    home.shellAliases = {
      ll = "ls -alF";

      # Nix workflow aliases
      switchcd = "cd ${config.home.homeDirectory}/${userSettings.repoPath}";
      switchupdate = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && nix flake update";
      switchcheck = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && nix flake check";
      switchtrusted = "nix config show | grep trusted-users";

      # --- terminal eye candy ---
      # Each toy runs under an idle inhibitor so the display stays on and
      # the host doesn't auto-suspend while it's running. The inhibit is
      # released when the toy exits.
      funmatrix = "${funWrap}unimatrix -s 96 -l o"; # Matrix rain (fast, iconic katakana set)
      funbonsai = "${funWrap}cbonsai -li"; # Live-growing ASCII bonsai, infinite loop
      funhack = "${funWrap}genact"; # Fake hacking activity generator
    };
  };
}
