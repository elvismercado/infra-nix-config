# Cross-platform development profile
#
# Composes the reusable tool modules for Linux and macOS. On macOS, the
# system-level app façade must also be enabled to install the VS Code cask.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/development.nix ];
#   custom.hmDevelopment.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmDevelopment;
  isLinux = lib.hasSuffix "linux" userSettings.system;
  isDarwin = lib.hasSuffix "darwin" userSettings.system;
  vscodeModule =
    if isLinux then
      ../linux/vscode.nix
    else if isDarwin then
      ../darwin/vscode.nix
    else
      throw "custom.hmDevelopment supports Linux and macOS hosts; got system '${userSettings.system}'";
in
{
  imports = [
    ./base.nix
    ./fnm.nix
    ./github-cli.nix
    ./git.nix
    ./ssh.nix
    ./uv.nix
    vscodeModule
  ];

  options.custom.hmDevelopment.enable = lib.mkEnableOption "cross-platform development tools";

  config = lib.mkIf cfg.enable {
    custom.hmFnm.enable = true;
    custom.hmGit.enable = true;
    custom.hmGitHubCli.enable = true;
    custom.hmSsh.enable = true;
    custom.hmUv.enable = true;
    custom.hmVscode.enable = true;
  };
}
