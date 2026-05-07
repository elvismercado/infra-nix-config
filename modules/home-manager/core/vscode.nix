# Visual Studio Code — shared cross-platform core
#
# Declares the `custom.hmVscode.enable` toggle and a shared `custom.hmVscode.settings`
# attrset used by both the Linux and Darwin wrappers. This file holds NO `config`
# block — wrappers own the actual writing because the mechanism differs per OS:
#
#   - Linux wrapper:  feeds `cfg.settings` to `programs.vscode.profiles.default.userSettings`
#                     (HM installs nixpkgs vscode and writes ~/.config/Code/User/settings.json).
#   - Darwin wrapper: bypasses `programs.vscode` entirely (HM's `programs.vscode`
#                     rejects `package = null`) and writes the same attrset
#                     directly to ~/Library/Application Support/Code/User/settings.json
#                     via `home.file`. The Homebrew cask provides the binary.
#
# `custom.hmVscode.settings` uses `attrsOf anything`, so hosts can extend or override
# per-key without replacing the whole map (module-system merging). VS Code's built-in
# defaults live inside the binary; settings.json only carries user overrides, so a
# minimal managed file does NOT suppress unmentioned options.
#
# Internal — do not import from hosts. Imported by `linux/vscode.nix` and `darwin/vscode.nix`.
# In normal use, hosts wire VS Code through the Option 3 app façade
# (`modules/apps/{darwin,linux}/vscode.nix`, toggle `custom.appVscode.enable`),
# which auto-imports the matching wrapper and flips `custom.hmVscode.enable` for them.
# Direct host-side use of `custom.hmVscode.enable` is discouraged.
#
# Canonical Option 2 exemplar — see [.github/instructions/cross-platform.instructions.md](../../../.github/instructions/cross-platform.instructions.md).

{ lib, ... }:

{
  options.custom.hmVscode = {
    enable = lib.mkEnableOption "Visual Studio Code with declarative settings";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        # Disable update notifications — VS Code is managed by Nix on Linux
        # and by Homebrew cask on Darwin. The built-in updater should not run.
        "update.mode" = "none";
        "extensions.autoCheckUpdates" = false;
        "extensions.autoUpdate" = false;
      };
      description = ''
        VS Code user settings written to settings.json on every host.

        Used by the Linux wrapper via `programs.vscode.profiles.default.userSettings`
        and by the Darwin wrapper via `home.file` (the cask binary doesn't read
        the nixpkgs HM module path).

        Hosts may extend or override individual keys; defaults merge with host-side
        definitions per `attrsOf` semantics.
      '';
    };
  };

  # No `config` block — wrappers own the per-OS write mechanism.
}
