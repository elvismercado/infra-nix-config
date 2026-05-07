# Rectangle — window tiling for macOS with unified Cmd+Option shortcuts
# https://rectangleapp.com
#
# Configures Rectangle keyboard shortcuts to match the unified Meta+Alt
# tiling scheme used on Linux (KDE) and Windows (PowerToys).
#
# On macOS, "Meta+Alt" maps to Cmd+Option (⌘⌥).
#
# Rectangle must be installed separately (e.g. `brew install --cask rectangle`
# or via nix-darwin's homebrew.casks). This module only configures shortcuts.
#
# Shortcut scheme:
#   Halves:   Cmd+Option + Arrow keys (Left/Right/Up/Down)
#   Quarters: Cmd+Option + U (top-left), I (top-right),
#                            J (bottom-left), K (bottom-right)
#   Center:   Cmd+Option + C
#   Maximize: Cmd+Option + Return
#   Restore:  Cmd+Option + Backspace
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/rectangle.nix ];
#   custom.hmRectangle.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.hmRectangle.enable = lib.mkEnableOption "Rectangle window tiling for macOS with unified Cmd+Option shortcuts";
  };

  config = lib.mkIf config.custom.hmRectangle.enable {
    # Configure Rectangle shortcuts via defaults write on activation.
    # modifierFlags 1572864 = Cmd+Option (⌘⌥)
    # Key codes: Left=123, Right=124, Up=126, Down=125,
    #            U=32, I=34, J=38, K=40, C=8, Return=36, Delete=51
    home.activation.rectangleShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DOMAIN="com.knollsoft.Rectangle"

      # Disable default shortcuts so only our custom ones are active
      /usr/bin/defaults write "$DOMAIN" alternateDefaultShortcuts -bool false

      # ── Halves ──────────────────────────────────────────────────
      /usr/bin/defaults write "$DOMAIN" leftHalf     -dict keyCode -int 123 modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" rightHalf    -dict keyCode -int 124 modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" topHalf      -dict keyCode -int 126 modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" bottomHalf   -dict keyCode -int 125 modifierFlags -int 1572864

      # ── Quarters ────────────────────────────────────────────────
      /usr/bin/defaults write "$DOMAIN" topLeft      -dict keyCode -int 32  modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" topRight     -dict keyCode -int 34  modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" bottomLeft   -dict keyCode -int 38  modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" bottomRight  -dict keyCode -int 40  modifierFlags -int 1572864

      # ── Center / Maximize / Restore ────────────────────────────
      /usr/bin/defaults write "$DOMAIN" center       -dict keyCode -int 8   modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" maximize     -dict keyCode -int 36  modifierFlags -int 1572864
      /usr/bin/defaults write "$DOMAIN" restore      -dict keyCode -int 51  modifierFlags -int 1572864

      # Launch on login
      /usr/bin/defaults write "$DOMAIN" launchOnLogin -bool true
    '';
  };
}
