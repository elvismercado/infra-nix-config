# Visual Studio Code — Darwin app façade
#
# Cross-layer module that owns BOTH the Homebrew cask (binary) and the
# matching home-manager config under one toggle. Hosts wire VS Code on
# darwin by importing this file from `configuration/default.nix` and
# enabling `custom.appVscode.enable` — they should NOT also touch
# `homebrew.casks` or `custom.hmVscode.enable` directly.
#
# Mechanics:
#   - Adds `visual-studio-code` to homebrew.casks.
#   - Injects `modules/home-manager/darwin/vscode.nix` into HM scope and
#     flips `custom.hmVscode.enable = true` for the configured user.
#   - The HM darwin wrapper sets `programs.vscode.package = null`, so HM
#     writes settings.json without installing a second VS Code from nixpkgs.
#
# Canonical Option 3 exemplar — see
# [.github/instructions/cross-platform.instructions.md](../../../.github/instructions/cross-platform.instructions.md).
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/vscode.nix ];
#   custom.appVscode.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appVscode;
in
{
  options.custom.appVscode.enable = lib.mkEnableOption "Visual Studio Code (Homebrew cask binary + declarative HM settings)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "visual-studio-code" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/vscode.nix ];
      custom.hmVscode.enable = true;
    };
  };
}
