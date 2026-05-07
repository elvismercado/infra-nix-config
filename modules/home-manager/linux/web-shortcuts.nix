# Web shortcuts — Linux wrapper for the cross-platform web-shortcuts core.
#
# Renders each `custom.hmWebShortcuts.entries.<key>` as a FreeDesktop
# `~/Desktop/<key>.desktop` launcher invoking `xdg-open <url>`.
#
# Internal — imported by app modules that want to expose a Web UI shortcut
# (e.g. `modules/home-manager/linux/syncthing.nix`). Hosts may also import
# directly to register ad-hoc shortcuts.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/web-shortcuts.nix ];
#   custom.hmWebShortcuts.enable = true;
#   custom.hmWebShortcuts.entries.syncthing = {
#     name = "Syncthing Web UI";
#     url  = "http://127.0.0.1:8384";
#   };

{ config, lib, ... }:

let
  cfg = config.custom.hmWebShortcuts;

  mkDesktop = key: entry: {
    name = "Desktop/${key}.desktop";
    value = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=${entry.name}
        ${lib.optionalString (entry.comment != null) "Comment=${entry.comment}"}
        Exec=xdg-open ${entry.url}
        Icon=${entry.icon}
        Categories=Network;
        Terminal=false
      '';
      executable = true;
    };
  };
in
{
  imports = [ ../core/web-shortcuts.nix ];

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs' mkDesktop cfg.entries;
  };
}
