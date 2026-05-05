# XDG autostart entries — declarative ~/.config/autostart/*.desktop files
#
# Generates freedesktop autostart entries that the desktop environment
# launches on user login. KDE Plasma, GNOME, and other XDG-compliant
# sessions all honour these. Tray-friendly defaults are baked in
# (Hidden=false, Terminal=false, X-KDE-autostart-after=panel).
#
# This module only writes desktop files — it does not install the apps.
# Each Exec= must resolve on PATH (install via the relevant module or
# home.packages).
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/autostart.nix ];
#   custom.hmAutostart = {
#     enable = true;
#     entries = {
#       vesktop = {
#         name = "Vesktop";
#         exec = "vesktop --start-minimized";
#         icon = "vesktop";
#       };
#       steam = {
#         name = "Steam";
#         exec = "steam -silent";
#         icon = "steam";
#       };
#     };
#   };

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmAutostart;

  entryType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "Vesktop";
        description = "Display name written to the Name= key.";
      };
      exec = lib.mkOption {
        type = lib.types.str;
        example = "vesktop --start-minimized";
        description = "Command to run, written to the Exec= key. Must be on PATH.";
      };
      icon = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "vesktop";
        description = "Optional icon name (XDG icon spec) or absolute path.";
      };
      comment = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional Comment= text shown in tooltips.";
      };
      terminal = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the program runs in a terminal.";
      };
    };
  };

  renderEntry =
    entry:
    let
      lines = [
        "[Desktop Entry]"
        "Type=Application"
        "Name=${entry.name}"
        "Exec=${entry.exec}"
        "Terminal=${if entry.terminal then "true" else "false"}"
        "Hidden=false"
        "X-GNOME-Autostart-enabled=true"
        # Wait for the Plasma panel/system tray to exist so apps that "minimize
        # to tray" don't pop a window when no tray is ready yet. Harmless on
        # other DEs.
        "X-KDE-autostart-after=panel"
      ]
      ++ lib.optional (entry.icon != null) "Icon=${entry.icon}"
      ++ lib.optional (entry.comment != null) "Comment=${entry.comment}";
    in
    lib.concatStringsSep "\n" lines + "\n";
in

{
  options = {
    custom.hmAutostart = {
      enable = lib.mkEnableOption "XDG autostart entries (writes ~/.config/autostart/*.desktop)";
      entries = lib.mkOption {
        type = lib.types.attrsOf entryType;
        default = { };
        description = ''
          Attribute set of autostart entries. The attribute name becomes the
          desktop-file basename (e.g. `vesktop` → `vesktop.desktop`).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = lib.mapAttrs' (slug: entry: {
      name = "autostart/${slug}.desktop";
      value = {
        text = renderEntry entry;
      };
    }) cfg.entries;
  };
}
