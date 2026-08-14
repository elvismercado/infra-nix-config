# KWin Custom Tile Layouts — declarative per-monitor zones
# https://invent.kde.org/plasma/kwin
#
# Plasma 6 supports custom tile layouts (Meta+T in tile-edit mode draws
# zones; Quick Tile shortcuts and Shift+drag snap windows into them).
# Layouts live in ~/.config/kwinrc under sections keyed by
# (virtual desktop UUID × output UUID):
#
#   [Tiling][<desktopUuid>][<outputUuid>]
#   tiles={"layoutDirection":"horizontal","tiles":[...]}
#
# Two non-obvious format rules KWin enforces:
#   1. Section path is THREE nested groups: Tiling / desktopUuid / outputUuid.
#   2. The root tile MUST have layoutDirection = "horizontal". To make
#      a vertical-only layout, wrap a vertical sub-tree in a single
#      horizontal child with width = 1.
#
# This module declares those layouts in Nix without ever pasting a UUID:
# host config keys layouts by DRM connector name (e.g. "DP-2"), and a
# home-manager activation script resolves connector → output UUID by
# reading KWin's own ~/.config/kwinoutputconfig.json, then writes the
# matching section for every virtual desktop discovered in
# ~/.config/kwinrc. Connectors / files that aren't yet present are
# logged and skipped, so first-install / hot-plug scenarios don't break
# rebuilds.
#
# Bootstrap caveat: kwinoutputconfig.json and kwinrc[Desktops] are
# created by KWin on first session start. On a brand-new user account
# the very first `home-manager switch` will skip all layouts. Log into
# KDE once, then re-run the switch — UUIDs are stable thereafter. KWin
# generates and persists output UUIDs, associating them with outputs via
# EDID identity, MST path, and connector information; desktop UUIDs
# survive logouts.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/kwin-tiling.nix ];
#   custom.hmKwinTiling.enable = true;
#   custom.hmKwinTiling.layouts.m2 = {
#     connector = "DP-2";
#     tiles = {
#       layoutDirection = "horizontal";
#       tiles = [{
#         layoutDirection = "vertical";
#         width = 1;
#         tiles = [
#           { height = 0.333; }
#           { height = 0.333; }
#           { height = 0.334; }
#         ];
#       }];
#     };
#   };
#
# Troubleshooting:
#   - Layout missing after switch?  Activation log appears inline during
#     `nixos-rebuild switch` / `home-manager switch` (look for
#     "[kwin-tiling] no UUID" or "no virtual desktops" — KWin hasn't
#     written its config yet on a fresh account; log in once and re-run).
#   - Confirm the value:
#       OUUID=$(jq -r --arg c DP-2 \
#         '.[] | select(.name=="outputs") | .data[] | select(.connectorName==$c) | .uuid' \
#         ~/.config/kwinoutputconfig.json)
#       DUUID=$(kreadconfig6 --file kwinrc --group Desktops --key Id_1)
#       kreadconfig6 --file kwinrc --group Tiling --group "$DUUID" --group "$OUUID" --key tiles
#   - Apply without re-login: KWin re-reads kwinrc on next tile-edit
#     mode toggle (Meta+T) or session restart.

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
          layoutDirection = "horizontal";
          tiles = [
            {
              layoutDirection = "vertical";
              width = 1;
              tiles = [
                { height = 0.5; }
                { height = 0.5; }
              ];
            }
          ];
        };
        description = ''
          Tile tree (recursive). Root MUST have layoutDirection = "horizontal".
          Serialized to JSON and stored under
          `[Tiling][<desktopUuid>][<outputUuid>]` in kwinrc.
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
        Each layout's tile tree is written to every virtual desktop's
        section for the resolved output UUID.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmKwinTiling requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
      {
        assertion = lib.all (l: (l.tiles.layoutDirection or null) == "horizontal") (
          lib.attrValues cfg.layouts
        );
        message = ''
          custom.hmKwinTiling.layouts: every layout's root `tiles.layoutDirection`
          must be "horizontal" (KWin requirement). Wrap vertical layouts in a
          horizontal parent with a single child carrying `width = 1`.
        '';
      }
    ];

    home.packages = with pkgs.kdePackages; [
      kconfig # kwriteconfig6 / kreadconfig6
    ];

    home.activation.hmKwinTiling = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      let
        # Render each layout to a json file so the script can read the
        # exact serialized form without embedding fragile shell strings.
        layoutEntries = lib.mapAttrsToList (name: l: {
          inherit name;
          inherit (l) connector;
          jsonFile = pkgs.writeText "kwin-tiling-${name}.json" (builtins.toJSON l.tiles);
        }) cfg.layouts;

        emitEntry = e: ''
          apply_layout ${lib.escapeShellArg e.name} ${lib.escapeShellArg e.connector} ${e.jsonFile}
        '';
      in
      ''
        export PATH=${
          lib.makeBinPath [
            pkgs.kdePackages.kconfig
            pkgs.jq
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
          ]
        }:$PATH

        OUTPUT_CONFIG="$HOME/.config/kwinoutputconfig.json"
        KWINRC="$HOME/.config/kwinrc"

        log() {
          # Activation runs during `home-manager switch` / `nixos-rebuild switch`,
          # not under a systemd unit, so stderr is the right channel — the
          # rebuild command echoes it inline. Matches display-profiles.nix.
          echo "[kwin-tiling] $*" >&2
        }

        # Collect every virtual-desktop UUID from kwinrc [Desktops] Id_N keys.
        # kreadconfig6 has no "list keys", so parse the INI directly.
        desktop_uuids() {
          [ -f "$KWINRC" ] || return 0
          sed -n '/^\[Desktops\]$/,/^\[/p' "$KWINRC" \
            | grep -oE '^Id_[0-9]+=.*$' \
            | sed -E 's/^Id_[0-9]+=//' \
            | grep -E '^[0-9a-f-]{36}$' || true
        }

        apply_layout() {
          local name="$1" connector="$2" json_file="$3"
          local output_uuid tiles_json wrote_any=0

          if [ ! -f "$OUTPUT_CONFIG" ]; then
            log "$OUTPUT_CONFIG missing (KWin has never run for this user?); skipping layout '$name' ($connector)"
            return 0
          fi
          if [ ! -f "$KWINRC" ]; then
            log "$KWINRC missing (KWin has never run for this user?); skipping layout '$name' ($connector)"
            return 0
          fi

          # KWin stores its generated, persistent output UUIDs in
          # kwinoutputconfig.json.
          output_uuid=$(jq -r --arg c "$connector" \
            '.[] | select(.name == "outputs") | .data[]? | select(.connectorName == $c) | .uuid // empty' \
            "$OUTPUT_CONFIG" 2>/dev/null)

          if [ -z "$output_uuid" ]; then
            log "no output UUID for $connector in kwinoutputconfig.json (monitor not currently known to KWin?), skipping layout '$name'"
            return 0
          fi

          tiles_json=$(cat "$json_file")

          # Apply to every known virtual desktop. KWin stores tile layouts
          # per (desktop × output); without per-desktop entries the layout
          # would only show on whichever desktop was active when KWin
          # first wrote its defaults.
          while IFS= read -r desktop_uuid; do
            [ -z "$desktop_uuid" ] && continue
            $DRY_RUN_CMD kwriteconfig6 \
              --file "$KWINRC" \
              --group "Tiling" --group "$desktop_uuid" --group "$output_uuid" \
              --key tiles "$tiles_json"
            wrote_any=1
            log "wrote layout '$name' for $connector ($output_uuid) on desktop $desktop_uuid"
          done < <(desktop_uuids)

          if [ "$wrote_any" -eq 0 ]; then
            log "no virtual desktops found in $KWINRC [Desktops]; skipping layout '$name'"
          fi
        }

        ${lib.concatStrings (map emitEntry layoutEntries)}
      ''
    );
  };
}
