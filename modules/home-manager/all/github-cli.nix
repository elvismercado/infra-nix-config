# GitHub CLI
#
# Installs gh. Authentication remains a manual per-user step with gh auth login.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/github-cli.nix ];
#   custom.hmGitHubCli.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.custom.hmGitHubCli.enable = lib.mkEnableOption "GitHub CLI";

  config = lib.mkIf config.custom.hmGitHubCli.enable {
    home.packages = [ pkgs.gh ];
  };
}
