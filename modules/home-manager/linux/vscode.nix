# Visual Studio Code — Linux wrapper for the cross-platform vscode core module.
#
# On Linux, home-manager installs VS Code from nixpkgs (the home-manager default
# package) and manages extensions and settings declaratively. No OS-specific
# overrides needed — all config lives in `../core/vscode.nix`.
#
# Internal once the Option 3 app façade is in use: this wrapper is auto-imported
# by `modules/apps/linux/vscode.nix` (toggle `custom.appVscode.enable`). Hosts
# should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/vscode.nix ];
#   custom.hmVscode.enable = true;

{ ... }:

{
  imports = [ ../core/vscode.nix ];
}
