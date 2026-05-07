# Visual Studio Code — Darwin wrapper for the cross-platform vscode core module.
#
# Binary is provided by the Homebrew cask `visual-studio-code` (declared by the
# Option 3 app façade in `modules/apps/darwin/vscode.nix`). This module sets
# `programs.vscode.package = null` so home-manager only writes the
# `~/Library/Application Support/Code/User/settings.json` file without
# installing a second VS Code copy from nixpkgs.
#
# Extensions are forced to an empty list because they should be installed
# through the cask-managed VS Code Marketplace UI on macOS — Nix-built
# extensions cannot be loaded by the cask binary.
#
# Internal once the Option 3 app façade is in use: this wrapper is auto-imported
# by `modules/apps/darwin/vscode.nix` (toggle `custom.appVscode.enable`). Hosts
# should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/darwin/vscode.nix ];
#   custom.hmVscode.enable = true;

{
  config,
  lib,
  ...
}:

{
  imports = [ ../core/vscode.nix ];

  config = lib.mkIf config.custom.hmVscode.enable {
    programs.vscode = {
      package = null; # Cask provides the binary
      profiles.default.extensions = lib.mkForce [ ];
    };
  };
}
