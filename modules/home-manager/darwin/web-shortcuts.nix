# Web shortcuts — Darwin wrapper for the cross-platform web-shortcuts core.
#
# Renders each `custom.hmWebShortcuts.entries.<key>` as an Apple `.webloc`
# URL bookmark plist at `~/Desktop/<key>.webloc`. Double-clicking opens the
# URL in the default browser; Spotlight indexes the display name from the
# filename.
#
# `comment` and `icon` from the core entry schema are accepted but ignored
# here — the .webloc format has no slot for either, and custom Finder icons
# require non-declarative resource-fork / extended-attribute writes.
#
# Internal — imported by app modules that want to expose a Web UI shortcut
# (e.g. `modules/home-manager/darwin/syncthing.nix`). Hosts may also import
# directly to register ad-hoc shortcuts.
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/web-shortcuts.nix ];
#   custom.hmWebShortcuts.enable = true;
#   custom.hmWebShortcuts.entries.syncthing = {
#     name = "Syncthing Web UI";
#     url  = "http://127.0.0.1:8384";
#   };

{ config, lib, ... }:

let
  cfg = config.custom.hmWebShortcuts;

  mkWebloc = key: entry: {
    name = "Desktop/${key}.webloc";
    value = {
      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyLists-1.0.dtd">
        <plist version="1.0">
        <dict>
        	<key>URL</key>
        	<string>${entry.url}</string>
        </dict>
        </plist>
      '';
    };
  };
in
{
  imports = [ ../core/web-shortcuts.nix ];

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs' mkWebloc cfg.entries;
  };
}
