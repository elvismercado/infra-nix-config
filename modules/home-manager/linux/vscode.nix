# Visual Studio Code — Linux wrapper for the cross-platform vscode core module.
#
# On Linux, home-manager installs VS Code from nixpkgs and writes settings via
# `programs.vscode.profiles.default.userSettings`. The shared `custom.hmVscode.settings`
# attrset (defined in core) feeds that option, so editing core affects every host.
# Extensions are Linux-only because the Homebrew cask binary on darwin cannot load
# Nix-built extensions.
#
# Internal once the Option 3 app façade is in use: this wrapper is auto-imported
# by `modules/apps/linux/vscode.nix` (toggle `custom.appVscode.enable`). Hosts
# should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/vscode.nix ];
#   custom.hmVscode.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmVscode;
in
{
  imports = [ ../core/vscode.nix ];

  config = lib.mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      profiles.default = {
        userSettings = cfg.settings;
        extensions = with pkgs.vscode-extensions; [
          jnoortheen.nix-ide # Nix support
          eamodio.gitlens # GitLens
          esbenp.prettier-vscode # Prettier formatter
        ];
      };
    };
  };
}
