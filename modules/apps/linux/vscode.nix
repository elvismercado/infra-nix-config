# Visual Studio Code — Linux app façade
#
# Cross-layer module that wires VS Code under the same `custom.appVscode.enable`
# toggle used on darwin. On Linux the binary comes from nixpkgs via home-manager
# (no system-layer cask needed), so this façade is a thin forwarder: it pulls
# the matching HM wrapper into HM scope and flips its enable toggle.
#
# This file exists for OS-symmetric host wiring — every host enables VS Code
# the same way (`custom.appVscode.enable = true;` in `configuration/default.nix`),
# regardless of OS. Hosts should NOT also touch `custom.hmVscode.enable` directly.
#
# Canonical Option 3 exemplar — see
# [.github/instructions/cross-platform.instructions.md](../../../.github/instructions/cross-platform.instructions.md).
#
# Usage:
#   imports = [ ../../../modules/apps/linux/vscode.nix ];
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
  options.custom.appVscode.enable = lib.mkEnableOption "Visual Studio Code (nixpkgs binary + declarative HM settings)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/vscode.nix ];
      custom.hmVscode.enable = true;
    };
  };
}
