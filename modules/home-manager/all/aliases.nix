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

  # Public flake repo + sibling private overlay checkout.
  # Convention (matches setup.sh / install.sh / flake.nix
  # `github:elvismercado/infra-nix-config-private`): the private repo lives
  # next to the public one on disk, so derive its path from
  # `repoPath`'s parent dir.
  publicRepo = "${config.home.homeDirectory}/${userSettings.repoPath}";
  privateRepo = "${config.home.homeDirectory}/${builtins.dirOf userSettings.repoPath}/infra-nix-config-private";
  workflowScript = "${publicRepo}/scripts/nix/switch-workflow.sh";
  publicRepoArg = lib.escapeShellArg publicRepo;
  privateRepoArg = lib.escapeShellArg privateRepo;
  workflowScriptArg = lib.escapeShellArg workflowScript;

  # Auth token for the private GitHub flake input. Evaluated at
  # alias-execution time by the user's shell - before any `sudo` - so
  # the token is captured from the user's `gh` CLI session and passed
  # through to nix (daemon or user-side). Required because the
  # `github:` URL scheme uses the GitHub tarball API, which honours
  # `access-tokens` but cannot use the git credential helper.
  # Prerequisite: `gh auth login` (one-time, per user per host).
  tokenOpt = ''--option access-tokens "github.com=$(gh auth token)"'';

  # Keep routine workflow output useful without entering debug-level noise.
  nixDiagnosticOpts = "--show-trace -v";
  nixBuildDiagnosticOpts = "${nixDiagnosticOpts} --print-build-logs";

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
      switchupdate = "cd ${publicRepo} && nix flake update ${tokenOpt} ${nixDiagnosticOpts}";
      switchcheck = "cd ${publicRepo} && nix flake check ${tokenOpt} ${nixBuildDiagnosticOpts}";
      switchtrusted = "nix config show | grep trusted-users";

      # Explicit one-shot: refresh the `private` lock entry, commit,
      # and push. Use after committing and pushing private overlay edits
      # to ship the resulting lock bump to other hosts.
      switchbumpprivate = "cd ${publicRepo} && nix flake update private ${tokenOpt} ${nixDiagnosticOpts} && git add --verbose flake.lock && (git diff --cached --quiet || git commit -m 'flake.lock: bump private input') && git push --verbose";

      # Automatic two-repository workflow and retryable publish helpers.
      switchpublish = "bash ${workflowScriptArg} publish-public ${publicRepoArg}";
      switchprivatepublish = "bash ${workflowScriptArg} publish-private ${privateRepoArg}";
      switchlogs = "bash ${workflowScriptArg} logs";

      # Git sync only. Input updates belong to switchupdate and the
      # automatic workflow; this command never changes flake.lock.
      switchpull = ''git -C ${publicRepo} pull --verbose --ff-only && '' +
        ''{ if [ -d ${privateRepo} ] && git -C ${privateRepo} remote get-url origin >/dev/null 2>&1; then '' +
        ''git -C ${privateRepo} pull --verbose --ff-only; '' +
        ''else echo "switchpull: private sibling missing or stub (no origin) - skipping"; fi; }'';

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
