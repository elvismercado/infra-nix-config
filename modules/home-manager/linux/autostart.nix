# XDG autostart entries — declarative ~/.config/autostart/*.desktop files
#
# Generates freedesktop autostart entries that the desktop environment
# launches on user login. KDE Plasma, GNOME, and other XDG-compliant
# sessions all honour these. Entries can be disabled declaratively with
# `enabled = false`; tray-friendly defaults remain enabled otherwise.
#
# This module only writes desktop files — it does not install the apps.
# Each Exec= must resolve on PATH (install via the relevant module or
# home.packages).
#
# Coexistence with app-installed autostart files: many apps (Steam, Ferdium,
# Discord clients, …) drop their own ~/.config/autostart/<app>.desktop on
# first launch. To avoid the home-manager "file already exists" abort and
# to play nice with the user's history, this module compares content at
# activation time:
#   - target absent          → install our symlink
#   - target == our content  → install our symlink (silent)
#   - target != our content  → back up to <target>.pre-hm.<unix-ts>, then
#                              install our symlink (logged warning)
#   - stale managed symlink  → replace
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
#         exec = "steam -silent %U";
#         icon = "steam";
#       };
#     };
#   };

{
  config,
  lib,
  pkgs,
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
      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the desktop environment launches the program at login.";
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
        "Hidden=${if entry.enabled then "false" else "true"}"
        "X-GNOME-Autostart-enabled=${if entry.enabled then "true" else "false"}"
        # Wait for the Plasma panel/system tray to exist so apps that "minimize
        # to tray" don't pop a window when no tray is ready yet. Harmless on
        # other DEs.
        "X-KDE-autostart-after=panel"
      ]
      ++ lib.optional (entry.icon != null) "Icon=${entry.icon}"
      ++ lib.optional (entry.comment != null) "Comment=${entry.comment}";
    in
    lib.concatStringsSep "\n" lines + "\n";

  # Materialize each rendered .desktop into the Nix store so we have a
  # stable path to symlink to AND to byte-compare against what's on disk.
  entrySources = lib.mapAttrs (
    slug: entry: pkgs.writeText "${slug}.desktop" (renderEntry entry)
  ) cfg.entries;
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
    home.activation.hmAutostart = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      autostartDir="$HOME/.config/autostart"
      $DRY_RUN_CMD mkdir -p "$autostartDir"

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (slug: src: ''
          target="$autostartDir/${slug}.desktop"
          source="${src}"

          if [ -L "$target" ]; then
            current="$(readlink "$target")"
            if [ "$current" = "$source" ]; then
              :  # already pointing at our store path
            else
              # Stale managed symlink (old generation) or foreign symlink.
              # If foreign and points to existing content that differs from
              # ours, back it up first.
              if [ -e "$current" ] && ! cmp -s "$current" "$source"; then
                backup="$target.pre-hm.$(date +%s)"
                $VERBOSE_ECHO "hmAutostart: ${slug}: foreign symlink differs, backing up target → $backup"
                $DRY_RUN_CMD cp -L "$target" "$backup"
              fi
              $DRY_RUN_CMD ln -sfn "$source" "$target"
            fi
          elif [ -e "$target" ]; then
            if cmp -s "$target" "$source"; then
              # Identical content — replace plain file with our symlink silently.
              $DRY_RUN_CMD ln -sfn "$source" "$target"
            else
              backup="$target.pre-hm.$(date +%s)"
              $VERBOSE_ECHO "hmAutostart: ${slug}: existing file differs, backing up → $backup"
              $DRY_RUN_CMD mv "$target" "$backup"
              $DRY_RUN_CMD ln -sfn "$source" "$target"
            fi
          else
            $DRY_RUN_CMD ln -sfn "$source" "$target"
          fi
        '') entrySources
      )}
    '';
  };
}
