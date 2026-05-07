# Web shortcuts — shared cross-platform core
#
# Declares a small registry of URL launcher shortcuts that wrappers render
# into platform-native files on the user's `~/Desktop`:
#
#   - Linux wrapper:  writes `~/Desktop/<key>.desktop` (FreeDesktop entry that
#                     invokes `xdg-open <url>`). Honours `comment` and `icon`.
#   - Darwin wrapper: writes `~/Desktop/<key>.webloc` (Apple URL bookmark
#                     plist). `comment` and `icon` are ignored — the .webloc
#                     format has no slot for either.
#
# Typical use: an app module (e.g. the syncthing wrappers) flips
# `custom.hmWebShortcuts.enable` and adds a single entry pointing at the
# app's local Web UI, so users get a clickable desktop icon to launch it.
#
# Internal — do not import from hosts. Imported by `linux/web-shortcuts.nix`
# and `darwin/web-shortcuts.nix`.

{ lib, ... }:

{
  options.custom.hmWebShortcuts = {
    enable = lib.mkEnableOption "URL desktop shortcuts (.desktop on linux, .webloc on darwin)";

    entries = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Display name shown for the shortcut.";
              };

              url = lib.mkOption {
                type = lib.types.str;
                example = "http://127.0.0.1:8384";
                description = "Destination URL opened when the shortcut is double-clicked.";
              };

              comment = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Tooltip / longer description (Linux only — ignored on darwin).";
              };

              icon = lib.mkOption {
                type = lib.types.str;
                default = "applications-internet";
                description = "FreeDesktop icon name (Linux only — ignored on darwin).";
              };
            };
          }
        )
      );
      default = { };
      description = ''
        Attribute set of URL shortcuts. The attribute key is used as the
        filename slug (e.g. `syncthing` → `syncthing.desktop` on linux and
        `syncthing.webloc` on darwin).
      '';
      example = lib.literalExpression ''
        {
          syncthing = {
            name = "Syncthing Web UI";
            url = "http://127.0.0.1:8384";
            comment = "Syncthing web interface";
          };
        }
      '';
    };
  };
}
