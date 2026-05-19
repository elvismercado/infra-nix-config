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
  # `github:elvismercado/nix-config-private`): the private repo lives
  # next to the public one on disk, so derive its path from
  # `repoPath`'s parent dir.
  publicRepo = "${config.home.homeDirectory}/${userSettings.repoPath}";
  privateRepo = "${config.home.homeDirectory}/${builtins.dirOf userSettings.repoPath}/nix-config-private";

  # Auth token for the private GitHub flake input. Evaluated at
  # alias-execution time by the user's shell - before any `sudo` - so
  # the token is captured from the user's `gh` CLI session and passed
  # through to nix (daemon or user-side). Required because the
  # `github:` URL scheme uses the GitHub tarball API, which honours
  # `access-tokens` but cannot use the git credential helper.
  # Prerequisite: `gh auth login` (one-time, per user per host).
  tokenOpt = ''--option access-tokens "github.com=$(gh auth token)"'';

  # Guarded one-liner that refreshes the `private` flake input lock
  # against the upstream GitHub repo. Silent no-op when the local
  # sibling clone is missing (gate kept so workflow stays consistent
  # with `switchbumpprivate` / `switchpull`). The `--flake` arg means
  # it works even when invoked from a different cwd. `2>/dev/null ||
  # true` swallows nix's "warning: updating lock file" noise and keeps
  # the alias chainable on `&&`.
  bumpPrivate = "{ if [ -d ${privateRepo} ] && git -C ${privateRepo} rev-parse --git-dir >/dev/null 2>&1; then nix flake update private --flake ${publicRepo} ${tokenOpt} 2>/dev/null || true; fi; }";
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
      switchupdate = "cd ${publicRepo} && nix flake update ${tokenOpt}";
      switchcheck = "cd ${publicRepo} && nix flake check ${tokenOpt}";
      switchtrusted = "nix config show | grep trusted-users";

      # Explicit one-shot: refresh the `private` lock entry, commit,
      # and push. Use after editing the private overlay to ship the
      # bump to other hosts. `switchcheck` / `switch` already refresh
      # the lock locally; this one persists the change.
      switchbumpprivate = "cd ${publicRepo} && nix flake update private ${tokenOpt} && git add flake.lock && git commit -m 'flake.lock: bump private input' && git push";

      # Git sync: fast-forward both the public repo and the private
      # sibling. Public failure aborts (--ff-only refuses on local
      # divergence). Private side is soft: missing dir or a stub repo
      # (no `origin` remote, as written by install.sh) prints a single
      # info line and exits 0 so the alias stays chainable.
      switchpull = ''git -C ${publicRepo} pull --ff-only && '' +
        ''{ if [ -d ${privateRepo} ] && git -C ${privateRepo} remote get-url origin >/dev/null 2>&1; then '' +
        ''git -C ${privateRepo} pull --ff-only; '' +
        ''else echo "switchpull: private sibling missing or stub (no origin) - skipping"; fi; } && '' +
        bumpPrivate;

      # --- terminal eye candy ---
      # Each toy runs under an idle inhibitor so the display stays on and
      # the host doesn't auto-suspend while it's running. The inhibit is
      # released when the toy exits.
      funmatrix = "${funWrap}unimatrix -s 82 -l o"; # Matrix rain (lively pace, iconic katakana set)
      funbonsai = "${funWrap}cbonsai -lit 0.08"; # Live-growing ASCII bonsai, infinite loop, slower step
      funhack = "${funWrap}genact"; # Fake hacking activity generator
    };
  };
}
