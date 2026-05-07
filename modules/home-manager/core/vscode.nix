# Visual Studio Code — shared cross-platform core
#
# Defines the `custom.hmVscode` option and shared declarative settings
# (update channel, extensions list) used by both the Linux and Darwin wrappers.
#
# Internal — do not import from hosts. Imported by `linux/vscode.nix` and `darwin/vscode.nix`.
# In normal use, hosts wire VS Code through the Option 3 app façade
# (`modules/apps/{darwin,linux}/vscode.nix`, toggle `custom.appVscode.enable`),
# which auto-imports the matching wrapper and flips this option for them.
# Direct host-side use of `custom.hmVscode.enable` is discouraged.
#
# Canonical Option 2 exemplar — see [.github/instructions/cross-platform.instructions.md](../../../.github/instructions/cross-platform.instructions.md).

{
  config,
  pkgs,
  lib,
  ...
}:

{
  options = {
    custom.hmVscode.enable = lib.mkEnableOption "Visual Studio Code with declarative extensions and settings";
  };

  config = lib.mkIf config.custom.hmVscode.enable {
    programs.vscode = {
      enable = true;
      profiles.default = {
        userSettings = {
          # Disable update notifications — VS Code is managed by Nix on Linux
          # and by Homebrew cask on Darwin. The built-in updater should not run.
          "update.mode" = "none";
          "extensions.autoCheckUpdates" = false;
          "extensions.autoUpdate" = false;
        };

        extensions = with pkgs.vscode-extensions; [
          jnoortheen.nix-ide # Nix support
          eamodio.gitlens # GitLens
          esbenp.prettier-vscode # Prettier formatter
        ];
      };
    };
  };
}
