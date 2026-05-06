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
# time by reading KWin's own ~/.config/kwinoutputconfig.json (the
# `outputs[].uuid` for the matching `connectorName`) and writes the
# resulting Tiling section with `kwriteconfig6`. Connectors that aren't
# currently present in that file are logged and skipped, so first-install
# / hot-plug scenarios don't break rebuilds.
#
# Bootstrap caveat: kwinoutputconfig.json is created by KWin on first
# session start. On a brand-new user account the very first
# `home-manager switch` will skip all layouts (no file yet). Log into
# KDE once, then re-run the switch — UUIDs are EDID-derived and stable
# thereafter (survive reboots and cable swaps).
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
#   - Layout missing after switch?  Activation log appears inline during
#     `nixos-rebuild switch` / `home-manager switch` (look for
#     "[kwin-tiling] no UUID for <connector>" — either the monitor was
#     unplugged at switch time, or KWin hasn't written its config yet on
#     a fresh account; log in once and re-run the switch).
#   - Confirm the value:
#       UUID=$(jq -r --arg c DP-2 \
#         '.[] | select(.name=="outputs") | .data[] | select(.connectorName==$c) | .uuid' \
#         ~/.config/kwinoutputconfig.json)
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
            pkgs.kdePackages.kconfig
            pkgs.jq
            pkgs.coreutils
          ]
        }:$PATH

        OUTPUT_CONFIG="$HOME/.config/kwinoutputconfig.json"

        log() {
          # Activation runs during `home-manager switch` / `nixos-rebuild switch`,
          # not under a systemd unit, so stderr is the right channel — the
          # rebuild command echoes it inline. Matches display-profiles.nix.
          echo "[kwin-tiling] $*" >&2
        }

        apply_layout() {
          local name="$1" connector="$2" json_file="$3"
          local uuid tiles_json

          if [ ! -f "$OUTPUT_CONFIG" ]; then
            log "$OUTPUT_CONFIG missing (KWin has never run for this user?); skipping layout '$name' ($connector)"
            return 0
          fi

          # KWin keys outputs by EDID-derived uuid in kwinoutputconfig.json.
          # That uuid is also what `[Tiling][<key>]` in kwintilerc expects.
          uuid=$(jq -r --arg c "$connector" \
            '.[] | select(.name == "outputs") | .data[]? | select(.connectorName == $c) | .uuid // empty' \
            "$OUTPUT_CONFIG" 2>/dev/null)

          if [ -z "$uuid" ]; then
            log "no UUID for $connector in kwinoutputconfig.json (monitor not currently known to KWin?), skipping layout '$name'"
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
