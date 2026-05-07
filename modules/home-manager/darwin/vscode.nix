# Visual Studio Code — Darwin wrapper for the cross-platform vscode core module.
#
# Binary is provided by the Homebrew cask `visual-studio-code` (declared by the
# Option 3 app façade in `modules/apps/darwin/vscode.nix`). This module bypasses
# `programs.vscode` entirely and writes settings.json directly via `home.file`.
#
# Why bypass `programs.vscode`?
#   In home-manager 25.11, `programs.vscode.package` is typed `package` (not
#   `nullOr package`) and the module dereferences `cfg.package.pname` to derive
#   `nameShort`, so `programs.vscode.package = null` fails to evaluate. We can't
#   feed it the nixpkgs vscode build either, because that would install a second
#   VS Code under /nix/store and shadow the cask binary on PATH (and violate
#   "no GUI apps via nixpkgs on macOS"). So on darwin we drop `programs.vscode`
#   altogether and write the same `cfg.settings` attrset that Linux feeds to
#   `programs.vscode.profiles.default.userSettings` directly to the path the
#   cask app reads at startup.
#
# Extensions: managed through the cask-installed VS Code Marketplace UI on macOS.
# Nix-built extensions cannot be loaded by the cask binary, so we don't try.
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

let
  cfg = config.custom.hmVscode;
in
{
  imports = [ ../core/vscode.nix ];

  config = lib.mkIf cfg.enable {
    home.file."Library/Application Support/Code/User/settings.json".text =
      builtins.toJSON cfg.settings;
  };
}
