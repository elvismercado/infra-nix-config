# Git — user identity, aliases, and delta diff pager
#
# Configures programs.git with user info derived from userSettings,
# common aliases, and delta for syntax-highlighted diffs.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/git.nix ];
#   custom.hmGit.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

{
  imports = [ ./github-cli.nix ];

  options = {
    custom.hmGit.enable = lib.mkEnableOption "Git with user identity, common aliases, and delta diff pager";
  };

  config = lib.mkIf config.custom.hmGit.enable {
    programs.git = {
      enable = true;

      settings = {
        user = {
          name = userSettings.username;
          email = "${userSettings.username}@${userSettings.hostname}";
        };

        alias = {
          st = "status";
          co = "checkout";
          br = "branch";
          ci = "commit";
          lg = "log --oneline --graph --decorate --all";
          last = "log -1 HEAD";
          unstage = "reset HEAD --";
          amend = "commit --amend --no-edit";
        };

        init.defaultBranch = "main";
        core.editor = config.custom.hmBase.editor;
        pull.rebase = false;
      } // lib.optionalAttrs config.custom.hmGitHubCli.enable {
        # Keep the helper paired with the optional CLI module. Git-only hosts
        # should not receive a credential helper for a missing gh executable.
        "credential.https://github.com".helper = "!gh auth git-credential";
      };
    };

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        navigate = true;
      };
    };
  };
}
