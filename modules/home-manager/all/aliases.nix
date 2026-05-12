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

  # Public flake repo + sibling private overlay.
  # Convention (matches setup.sh / install.sh / flake.nix
  # `git+file:../nix-config-private`): the private repo lives next to
  # the public one, so derive its path from `repoPath`'s parent dir.
  publicRepo = "${config.home.homeDirectory}/${userSettings.repoPath}";
  privateRepo = "${config.home.homeDirectory}/${builtins.dirOf userSettings.repoPath}/nix-config-private";
in

{
  options = {
    custom.hmAliases.enable = lib.mkEnableOption "cross-platform Home Manager shell aliases (nix workflow, diagnostics)";
  };

  config = lib.mkIf config.custom.hmAliases.enable {
    home.shellAliases = {
      ll = "ls -alF";

      # Nix workflow aliases
      switchcd = "cd ${publicRepo}";
      switchupdate = "cd ${publicRepo} && nix flake update";
      switchcheck = "cd ${publicRepo} && nix flake check";
      switchtrusted = "nix config show | grep trusted-users";

      # Git sync: fast-forward both the public repo and the private
      # sibling. Public failure aborts (--ff-only refuses on local
      # divergence). Private side is soft: missing dir or a stub repo
      # (no `origin` remote, as written by install.sh) prints a single
      # info line and exits 0 so the alias stays chainable.
      switchpull = ''git -C ${publicRepo} pull --ff-only && '' +
        ''{ if [ -d ${privateRepo} ] && git -C ${privateRepo} remote get-url origin >/dev/null 2>&1; then '' +
        ''git -C ${privateRepo} pull --ff-only; '' +
        ''else echo "switchpull: private sibling missing or stub (no origin) - skipping"; fi; }'';

      # --- terminal eye candy ---
      # Each toy runs under an idle inhibitor so the display stays on and
      # the host doesn't auto-suspend while it's running. The inhibit is
      # released when the toy exits.
      funmatrix = "${funWrap}unimatrix -s 70 -l o"; # Matrix rain (relaxed pace, iconic katakana set)
      funbonsai = "${funWrap}cbonsai -lit 0.08"; # Live-growing ASCII bonsai, infinite loop, slower step
      funhack = "${funWrap}genact"; # Fake hacking activity generator
    };
  };
}
