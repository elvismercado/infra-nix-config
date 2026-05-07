# Window Tiling Shortcuts — unified Meta+Alt keybindings
# https://github.com/nix-community/plasma-manager
#
# Configures consistent window tiling shortcuts using Meta+Alt as the
# modifier chord. Designed to match the same muscle-memory across
# Linux (this module), macOS (Rectangle), and Windows (PowerToys).
#
# Shortcut scheme:
#   Halves:        Meta+Alt + Arrow keys (Left/Right/Up/Down)
#   Quarters:      Meta+Alt + U (top-left), I (top-right),
#                              J (bottom-left), K (bottom-right)
#   Center:        Meta+Alt + C
#   Maximize:      Meta+Alt + Enter
#   Restore:       Meta+Alt + Backspace
#   Move screen:   Meta+Ctrl+Alt + Left/Right (cycle prev/next screen)
#   Direct screen: Meta+Alt + 1/2/3 (target KWin screen 0/1/2)
#
# Note: KWin's defaults bind Meta+Alt+Arrow to "Switch Window"
# (focus-switching between windows), and KDE Keyboard Layout Switcher
# binds Meta+Alt+K to "Switch to Next Keyboard Layout". This module
# unbinds those to avoid conflicts.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/window-shortcuts.nix ];
#   custom.hmWindowShortcuts.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

{
  options = {
    custom.hmWindowShortcuts.enable = lib.mkEnableOption "unified Meta+Alt KWin window-tiling shortcuts (matches Rectangle/PowerToys)";
  };

  config = lib.mkIf config.custom.hmWindowShortcuts.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmWindowShortcuts requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
    ];

    programs.plasma.shortcuts = {
      kwin = {
        # ── Unbind conflicting defaults ───────────────────────────────
        # KWin binds Meta+Alt+Arrow to "Switch Window" by default;
        # clear them so our Quick Tile bindings can use those keys.
        "Switch Window Down" = [ ];
        "Switch Window Left" = [ ];
        "Switch Window Right" = [ ];
        "Switch Window Up" = [ ];

        # ── Halves ────────────────────────────────────────────────────
        "Window Quick Tile Left" = "Meta+Alt+Left";
        "Window Quick Tile Right" = "Meta+Alt+Right";
        "Window Quick Tile Top" = "Meta+Alt+Up";
        "Window Quick Tile Bottom" = "Meta+Alt+Down";

        # ── Quarters ──────────────────────────────────────────────────
        "Window Quick Tile Top Left" = "Meta+Alt+U";
        "Window Quick Tile Top Right" = "Meta+Alt+I";
        "Window Quick Tile Bottom Left" = "Meta+Alt+J";
        "Window Quick Tile Bottom Right" = "Meta+Alt+K";

        # ── Center / Maximize / Restore ──────────────────────────────
        "Window Move Center" = "Meta+Alt+C";
        "Window Maximize" = "Meta+Alt+Return";
        "Window Restore" = "Meta+Alt+Backspace";
        # ── Move window across screens ─────────────────────────
        # Cycle by KWin screen index (0, 1, 2, … wraps around).
        "Window to Next Screen" = "Meta+Ctrl+Alt+Right";
        "Window to Previous Screen" = "Meta+Ctrl+Alt+Left";
        # Direct screen targets. KWin's screen index is its own ordering;
        # confirm 1/2/3 → M1/M2/M3 mapping after first use and re-bind if needed.
        "Window to Screen 0" = "Meta+Alt+1";
        "Window to Screen 1" = "Meta+Alt+2";
        "Window to Screen 2" = "Meta+Alt+3";
      };

      # ── Unbind keyboard layout switcher conflict ────────────────────
      # KDE binds Meta+Alt+K to "Switch to Next Keyboard Layout",
      # which conflicts with our bottom-right quarter tile shortcut.
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = [ ];
    };
  };
}
