# KWin Custom Tile Layouts — declarative per-monitor zones
# https://invent.kde.org/plasma/kwin
#
# Plasma 6 supports custom tile layouts (Meta+T in tile-edit mode draws
# zones; Quick Tile shortcuts and Shift+drag snap windows into them).
# Layouts are stored in ~/.config/kwintilerc, keyed by KScreen output
# UUID, with the tile tree as a JSON value.
#
# This module declares those layouts in Nix without ever pasting a UUID:
# host config keys layouts by DRM connector name (e.g. "DP-2"), and a
# home-manager activation script resolves connector → UUID at switch
# time via `kscreen-doctor -j` and writes the resulting Tiling section
# with `kwriteconfig6`. Connectors that aren't currently plugged in are
# logged and skipped, so first-install / hot-plug scenarios don't break
# rebuilds.
#
# Tile tree shape (becomes JSON via builtins.toJSON):
#   {
#     layoutDirection = "vertical";   # or "horizontal"
#     tiles = [
#       { height = 0.333; }            # leaf — uses height for vertical,
#       { height = 0.333; }            #         width for horizontal
#       { height = 0.334; }
#     ];
#   }
# Branches recurse: a leaf can be replaced with another { layoutDirection; tiles; }
# attrs to nest a sub-layout inside a zone.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/kwin-tiling.nix ];
#   custom.hmKwinTiling.enable = true;
#   custom.hmKwinTiling.layouts.m2 = {
#     connector = "DP-2";
#     tiles = {
#       layoutDirection = "vertical";
#       tiles = [
#         { height = 0.333; }
#         { height = 0.333; }
#         { height = 0.334; }
#       ];
#     };
#   };
#
# Troubleshooting:
#   - Layout missing after switch?  Check journalctl --user -t kwin-tiling
#     for "no UUID for <connector>" warnings (monitor unplugged at switch
#     time). Re-run `home-manager switch` once the monitor is connected.
#   - Confirm the value:
#       UUID=$(kscreen-doctor -j | jq -r '.outputs[] | select(.name=="DP-2") | .id')
#       kreadconfig6 --file kwintilerc --group Tiling --group "$UUID" --key tiles
#   - Apply without re-login: KWin re-reads kwintilerc on next layout
#     change; easiest is logout/login or `loginctl terminate-session`.

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmKwinTiling;

  layoutModule = lib.types.submodule {
    options = {
      connector = lib.mkOption {
        type = lib.types.str;
        example = "DP-2";
        description = ''
          DRM connector name to resolve to a KScreen UUID at activation time.
          Examples: "DP-1", "DP-2", "HDMI-A-1".
        '';
      };

      tiles = lib.mkOption {
        type = lib.types.attrs;
        example = {
          layoutDirection = "vertical";
          tiles = [
            { height = 0.5; }
            { height = 0.5; }
          ];
        };
        description = ''
          Tile tree (recursive). Serialized to JSON and stored as the
          `tiles` value under `[Tiling][<uuid>]` in kwintilerc.
        '';
      };
    };
  };
in
{
  options = {
    custom.hmKwinTiling.enable = lib.mkEnableOption "Declarative KWin custom tile layouts (auto-resolves monitor UUID at activation)";

    custom.hmKwinTiling.layouts = lib.mkOption {
      type = lib.types.attrsOf layoutModule;
      default = { };
      description = ''
        Map of layout-name → { connector, tiles }. Layout names are
        labels for your own organization (e.g. "m2", "ultrawide-3col").
        Each layout's tile tree is written to the section keyed by the
        UUID of its connector.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmKwinTiling requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
    ];

    home.packages = with pkgs.kdePackages; [
      libkscreen # kscreen-doctor
      kconfig # kwriteconfig6 / kreadconfig6
    ];

    home.activation.hmKwinTiling = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        # Render each layout to a (connector, json-file) pair so the
        # script can iterate them without embedding fragile strings.
        layoutEntries = lib.mapAttrsToList (name: l: {
          inherit name;
          inherit (l) connector;
          jsonFile = pkgs.writeText "kwin-tiling-${name}.json" (builtins.toJSON l.tiles);
        }) cfg.layouts;

        emitEntry =
          e:
          ''
            apply_layout ${lib.escapeShellArg e.name} ${lib.escapeShellArg e.connector} ${e.jsonFile}
          '';
      in
      ''
        export PATH=${
          lib.makeBinPath [
            pkgs.kdePackages.libkscreen
            pkgs.kdePackages.kconfig
            pkgs.jq
            pkgs.coreutils
          ]
        }:$PATH

        log() {
          # systemd-cat tags so journalctl --user -t kwin-tiling filters cleanly.
          if command -v systemd-cat >/dev/null 2>&1; then
            echo "$*" | systemd-cat -t kwin-tiling -p info
          fi
          $VERBOSE_ECHO "kwin-tiling: $*"
        }

        apply_layout() {
          local name="$1" connector="$2" json_file="$3"
          local outputs uuid tiles_json

          outputs=$(kscreen-doctor -j 2>/dev/null) || {
            log "kscreen-doctor failed; skipping layout '$name' ($connector)"
            return 0
          }

          uuid=$(printf '%s' "$outputs" | jq -r --arg c "$connector" \
            '.outputs[]? | select(.name == $c) | .id // empty')

          if [ -z "$uuid" ]; then
            log "no UUID for $connector (monitor not connected?), skipping layout '$name'"
            return 0
          fi

          tiles_json=$(cat "$json_file")
          $DRY_RUN_CMD kwriteconfig6 \
            --file "$HOME/.config/kwintilerc" \
            --group "Tiling" --group "$uuid" \
            --key tiles "$tiles_json"
          log "wrote layout '$name' for $connector ($uuid)"
        }

        ${lib.concatStrings (map emitEntry layoutEntries)}
      ''
    );
  };
}
