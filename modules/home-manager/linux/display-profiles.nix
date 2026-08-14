# Display Profiles — topology-based auto-configuration service
# https://invent.kde.org/plasma/libkscreen
#
# KDE Plasma only — uses kscreen-doctor (kdePackages.libkscreen) and
# reads KWin state. Module asserts `userSettings.desktopEnvironment ==
# "kde-plasma"` when enabled.
#
# Watches the display topology (connected outputs + resolutions) and
# automatically applies the best-matching profile. Handles:
#   - Dual-mode monitors (e.g. 4K ↔ 1080p hardware switch)
#   - Secondary monitor plugged/unplugged
#   - Primary monitor swaps (different monitor on the same connector)
#   - Hot-plugged unknown outputs (auto-enabled and placed right of the
#     rightmost output configured by the matched profile)
#
# Each profile defines match criteria (connector → resolution) and
# per-output settings (scale, refresh rate, orientation, brightness,
# position). The profile with the most matching outputs wins.
#
# Runs as a systemd user service that polls kscreen-doctor every
# N seconds and applies settings only when the matched profile changes.
#
# Usage:
#   imports = [
#     ../../../modules/home-manager/linux/display-profiles.nix
#   ];
#   custom.hmDisplayProfiles.enable = true;
#   custom.hmDisplayProfiles.profiles."4k-dual" = {
#     match."DP-1" = "3840x2160";
#     match."DP-2" = "1920x1200";
#     outputs."DP-1" = { resolution = "3840x2160"; scale = 1.5; refreshRate = 60; primary = true; };
#     outputs."DP-2" = { resolution = "1920x1200"; scale = 1.0; orientation = "right"; position = "right-of-DP-1"; };
#   };

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmDisplayProfiles;

  # Submodule for per-output configuration
  outputModule = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether this output should be enabled when the profile matches.
          Set false to explicitly disable an output declared in the
          profile. Outputs that are connected but **not** declared in the
          profile are auto-enabled and placed right of the rightmost
          declared output (see module header).
        '';
      };

      resolution = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "3840x2160";
        description = ''
          Resolution to set for this output (e.g. "3840x2160").
          Used together with refreshRate to build the mode command.
          Null = use current resolution.
        '';
      };

      scale = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        example = 1.5;
        description = "Display scale factor (e.g. 1.0, 1.5, 2.0). Null = don't touch.";
      };

      refreshRate = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 100;
        description = "Refresh rate in Hz. Null = don't touch.";
      };

      orientation = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "normal"
            "left"
            "right"
            "inverted"
          ]
        );
        default = null;
        example = "right";
        description = ''
          Output orientation/rotation.
            normal   = 0° (landscape)
            left     = 90° (portrait, top of screen on left)
            right    = 270° (reverse portrait, top of screen on right)
            inverted = 180° (upside down)
          Null = don't touch.
        '';
      };

      brightness = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.float (v: v >= 0.0 && v <= 1.0));
        default = null;
        example = 1.0;
        description = ''
          Brightness from 0.0 to 1.0. Requires DDC/CI support on
          desktop monitors (i2c-dev kernel module). Skipped gracefully
          if unsupported. Null = don't touch.
        '';
      };

      position = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "right-of-DP-1";
        description = ''
          Output position. Use one of:
            "right-of-CONNECTOR" — logical x = anchor's own x-offset +
              its logical width (rotation-aware: portrait references
              use their height as logical width). Anchor may itself be
              positioned with right-of/left-of — chains are resolved
              recursively (max depth 10).
            "left-of-CONNECTOR" — mirror of right-of; this output is
              placed so its right edge meets the anchor's left edge.
            "X,Y" — explicit pixel position (e.g. "1920,0").
          A warning is logged if the named anchor is not connected;
          the output then falls back to position "0,0".
          Null = don't touch.
        '';
      };

      primary = lib.mkOption {
        type = lib.types.bool;
        default = false;
        example = true;
        description = ''
          Mark this output as the primary display (where the panel,
          launcher, and new windows appear by default). At most one
          output per profile should be primary; if multiple are set,
          the last one applied wins. Default false leaves the priority
          untouched on this output.

          Internally maps to `kscreen-doctor output.<id>.priority.1`
          (Plasma 6 syntax). The legacy `output.<id>.primary` form was
          deprecated upstream.
        '';
      };
    };
  };

  # Submodule for a display profile
  profileModule = lib.types.submodule {
    options = {
      match = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        example = {
          "DP-1" = "3840x2160";
          "DP-2" = "1920x1200";
        };
        description = ''
          Match criteria: connector name → expected max resolution.
          All listed connectors must be connected AND have the
          specified resolution as their highest available mode for
          this profile to match. This uses the maximum available
          resolution (not current), so hardware mode switches are
          detected even when KWin hasn't changed the active mode.
          Connectors not listed are ignored (don't affect matching).
        '';
      };

      outputs = lib.mkOption {
        type = lib.types.attrsOf outputModule;
        default = { };
        description = "Per-output configuration to apply when this profile matches.";
      };
    };
  };

  # Orientation mapping for kscreen-doctor
  orientationMap = {
    "normal" = "normal";
    "left" = "left";
    "right" = "right";
    "inverted" = "inverted";
  };

  # Generate the profile data as JSON for the script to consume
  profilesJson = builtins.toJSON (
    lib.mapAttrs (_name: profile: {
      match = profile.match;
      outputs = lib.mapAttrs (_connector: out: {
        inherit (out) enable;
        resolution = out.resolution;
        scale = out.scale;
        refreshRate = out.refreshRate;
        orientation = if out.orientation != null then orientationMap.${out.orientation} else null;
        brightness = out.brightness;
        position = out.position;
        primary = out.primary;
      }) profile.outputs;
    }) cfg.profiles
  );

  # The polling script
  displayProfilesScript = pkgs.writeShellApplication {
    name = "display-profiles-daemon";
    runtimeInputs = [
      pkgs.kdePackages.libkscreen # kscreen-doctor
      pkgs.jq
      pkgs.coreutils
      pkgs.gnused
      pkgs.gnugrep
      pkgs.gawk
      pkgs.glib # gdbus (hotplug listener)
    ];
    text = ''
      set -euo pipefail

      PROFILES_JSON='${profilesJson}'
      POLL_INTERVAL=${toString cfg.pollInterval}
      LAST_PROFILE=""
      LAST_TOPOLOGY=""

      log() {
        echo "[display-profiles] $*" >&2
      }

      # Parse topology into a JSON map: connector → { id, resolution, currentResolution }
      # Uses DRM sysfs for max resolution (kscreen-doctor / KWin caches stale modes
      # when a dual-mode monitor reconnects with the same persisted output UUID).
      get_topology() {
        local raw
        raw=$(kscreen-doctor --outputs 2>/dev/null) || { echo "{}"; return; }

        # Step 1: Extract connector names, output IDs, current mode, and the
        # full mode list from kscreen-doctor. Outputs
        # "connector|id|currentRes|mode1 mode2 ..." per connected output,
        # where each modeN is "WxH@RR" with the leading "N:" index and any
        # "!"/"*" markers stripped.
        local parsed
        parsed=$(echo "$raw" | sed 's/\x1b\[[0-9;]*m//g' | awk '
          /^Output:/ {
            if (connector != "" && connected) {
              print connector "|" id "|" current_res "|" modes
            }
            id = $2
            connector = $3
            connected = 0
            current_res = ""
            modes = ""
          }
          /connected/ && !/disconnected/ {
            if (/^[[:space:]]+connected/) connected = 1
          }
          /Modes:/ || /^[[:space:]]+[0-9]+:[0-9]+x[0-9]+@/ {
            n = split($0, tokens, " ")
            for (i = 1; i <= n; i++) {
              if (tokens[i] ~ /^[0-9]+:[0-9]+x[0-9]+@/) {
                t = tokens[i]
                sub(/^[0-9]+:/, "", t)
                is_current = (t ~ /\*/)
                gsub(/[!*]/, "", t)
                if (is_current) {
                  ct = t
                  sub(/@.*/, "", ct)
                  current_res = ct
                }
                if (modes == "") modes = t; else modes = modes " " t
              }
            }
          }
          END {
            if (connector != "" && connected) {
              print connector "|" id "|" current_res "|" modes
            }
          }
        ')

        [ -z "$parsed" ] && { echo "{}"; return; }

        # Step 2: Build JSON with max resolution from DRM sysfs.
        # /sys/class/drm/card*-CONNECTOR/modes lists true hardware modes
        # (one "WxH" per line), bypassing KWin's mode-list caching.
        # Mode list (with refresh rates) comes from kscreen-doctor and is
        # emitted as a JSON array per output for pick_mode validation.
        local json="{"
        local first=1
        while IFS='|' read -r connector id current_res modes_str; do
          [ -z "$connector" ] && continue

          # Read max resolution from sysfs
          local max_res="" max_pixels=0
          local sysfs_path
          for sysfs_path in /sys/class/drm/card*-"''${connector}"/modes; do
            [ -f "$sysfs_path" ] || continue
            while IFS= read -r mode_line; do
              local w="''${mode_line%%x*}"
              local h="''${mode_line##*x}"
              local pixels=$((w * h))
              if [ "$pixels" -gt "$max_pixels" ]; then
                max_pixels=$pixels
                max_res="$mode_line"
              fi
            done < "$sysfs_path"
            break
          done

          # Fall back to current resolution if sysfs unavailable
          if [ -z "$max_res" ]; then
            max_res="$current_res"
            log "Warning: sysfs modes not found for $connector, using current resolution"
          fi

          # Build modes JSON array from space-separated list. Word-splitting
          # on $modes_str is intentional: it's a space-separated list of
          # "WxH@RR" tokens with no embedded whitespace.
          local modes_json="[]"
          if [ -n "$modes_str" ]; then
            # shellcheck disable=SC2086
            modes_json=$(printf '%s\n' $modes_str | jq -R . | jq -s -c .)
          fi

          [ "$first" -eq 0 ] && json+=","
          json+="\"''${connector}\":{\"id\":\"''${id}\",\"resolution\":\"''${max_res}\",\"currentResolution\":\"''${current_res}\",\"modes\":''${modes_json}}"
          first=0
        done <<< "$parsed"
        json+="}"

        echo "$json"
      }

      # Validate a requested resolution+rate against an output's actual mode
      # list. Echoes the mode string to use as the kscreen-doctor `mode.` arg
      # (e.g. "3840x2160@60") and logs a warning when falling back. Echoes an
      # empty string if no mode at the requested resolution exists at all
      # (caller should then skip the mode arg entirely).
      #
      # Strategy:
      #   1. Exact integer-rate match (e.g. requested 60 matches "...@60.00").
      #   2. Same resolution, closest available rate -- with a warning.
      #   3. Resolution unavailable -- empty + warning.
      pick_mode() {
        local connector="$1"
        local topology="$2"
        local want_res="$3"
        local want_rate="$4"

        # Pull the modes array; default to empty if missing.
        local modes_json
        modes_json=$(echo "$topology" | jq -c --arg c "$connector" '.[$c].modes // []')

        # If we have no list at all (older kscreen-doctor / parser fallback),
        # trust the caller and just echo the requested mode.
        if [ "$modes_json" = "[]" ] || [ -z "$modes_json" ]; then
          if [ -n "$want_rate" ]; then
            echo "''${want_res}@''${want_rate}"
          else
            echo "$want_res"
          fi
          return
        fi

        # All rates available at the requested resolution.
        local rates
        rates=$(echo "$modes_json" | jq -r --arg r "$want_res" '
          map(select(startswith($r + "@")) | sub("^.*@"; "") | tonumber) | .[]
        ')

        if [ -z "$rates" ]; then
          log "  Warning: $connector has no mode at resolution $want_res -- skipping mode arg"
          echo ""
          return
        fi

        # No rate requested -- just echo the resolution.
        if [ -z "$want_rate" ]; then
          echo "$want_res"
          return
        fi

        # Exact integer-rate match wins.
        local exact
        exact=$(echo "$rates" | awk -v r="$want_rate" '{ if (int($1) == int(r)) { print $1; exit } }')
        if [ -n "$exact" ]; then
          echo "''${want_res}@''${want_rate}"
          return
        fi

        # Closest available rate.
        local closest
        closest=$(echo "$rates" | awk -v r="$want_rate" '
          BEGIN { best = -1; best_diff = 1e9 }
          {
            d = $1 - r; if (d < 0) d = -d
            if (d < best_diff) { best_diff = d; best = $1 }
          }
          END { if (best >= 0) printf "%g", best }
        ')

        if [ -n "$closest" ]; then
          log "  Warning: $connector requested ''${want_res}@''${want_rate} unavailable, using ''${want_res}@''${closest}"
          # kscreen-doctor accepts both "60" and "60.00" -- pass the actual
          # advertised rate verbatim so the match is unambiguous.
          echo "''${want_res}@''${closest}"
          return
        fi

        # Defensive fallback (should be unreachable).
        echo "$want_res"
      }

      # Find the best matching profile for the current topology
      find_best_profile() {
        local topology="$1"
        echo "$PROFILES_JSON" | jq -r --argjson topo "$topology" '
          # For each profile, count how many match entries are satisfied
          to_entries | map(
            .key as $name |
            .value.match as $match |
            {
              name: $name,
              score: (
                [ $match | to_entries[] |
                  select(
                    $topo[.key] != null and
                    $topo[.key].resolution == .value
                  )
                ] | length
              ),
              total: ($match | length)
            } |
            # Only consider profiles where ALL match entries are satisfied
            select(.score == .total and .score > 0)
          ) |
          # Sort by score descending, then name ascending for deterministic ties
          sort_by([-.score, .name]) |
          first // empty |
          .name
        '
      }

      # Get the output config for a profile
      get_profile_outputs() {
        local profile_name="$1"
        echo "$PROFILES_JSON" | jq -c --arg name "$profile_name" '.[$name].outputs'
      }

      # Calculate logical width of an output, accounting for rotation and scale.
      # Portrait orientations (left/right) swap WxH for on-screen logical width.
      # Echoes an integer; "0" if the output's resolution is unknown.
      calc_logical_width() {
        local connector="$1"
        local topology="$2"
        local profile_outputs="$3"

        local res
        res=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].resolution // empty')
        if [ -z "$res" ]; then
          res=$(echo "$topology" | jq -r --arg c "$connector" '.[$c].currentResolution // empty')
        fi
        if [ -z "$res" ]; then
          echo "0"
          return
        fi

        local w h
        w=$(echo "$res" | cut -d'x' -f1)
        h=$(echo "$res" | cut -d'x' -f2)

        local orientation
        orientation=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].orientation // empty')
        local logical_w="$w"
        if [ "$orientation" = "left" ] || [ "$orientation" = "right" ]; then
          logical_w="$h"
        fi

        local scale
        scale=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].scale // 1')

        # Round to nearest integer (not truncate) so fractional scales like
        # 1.7 don't leave a 1px gap/overlap with right-of neighbors. Plasma's
        # own logical-extent calculation rounds (qRound), so matching that
        # avoids QTBUG-129989-style fullscreen-screen-misresolution bugs.
        awk "BEGIN { printf \"%.0f\", $logical_w / $scale }"
      }

      # Recursively resolve the absolute logical x-offset of an output by
      # walking its `position` chain (right-of/left-of/literal). Returns 0
      # for outputs with no position. Warns and returns 0 if the chain
      # exceeds MAX_POSITION_DEPTH or references a missing anchor.
      MAX_POSITION_DEPTH=10
      calc_x_offset() {
        local connector="$1"
        local topology="$2"
        local profile_outputs="$3"
        local depth="$4"

        if [ "$depth" -ge "$MAX_POSITION_DEPTH" ]; then
          log "  Warning: position chain depth exceeded $MAX_POSITION_DEPTH at $connector — falling back to 0"
          echo "0"
          return
        fi

        local position
        position=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].position // empty')
        if [ -z "$position" ]; then
          echo "0"
          return
        fi

        if [[ "$position" == right-of-* ]]; then
          local anchor="''${position#right-of-}"
          local anchor_id
          anchor_id=$(echo "$topology" | jq -r --arg c "$anchor" '.[$c].id // empty')
          if [ -z "$anchor_id" ]; then
            log "  Warning: position anchor '$anchor' not connected for $connector — falling back to 0"
            echo "0"
            return
          fi
          local anchor_x anchor_w
          anchor_x=$(calc_x_offset "$anchor" "$topology" "$profile_outputs" $((depth + 1)))
          anchor_w=$(calc_logical_width "$anchor" "$topology" "$profile_outputs")
          awk "BEGIN { printf \"%.0f\", $anchor_x + $anchor_w }"
          return
        fi

        if [[ "$position" == left-of-* ]]; then
          local anchor="''${position#left-of-}"
          local anchor_id
          anchor_id=$(echo "$topology" | jq -r --arg c "$anchor" '.[$c].id // empty')
          if [ -z "$anchor_id" ]; then
            log "  Warning: position anchor '$anchor' not connected for $connector — falling back to 0"
            echo "0"
            return
          fi
          local anchor_x self_w
          anchor_x=$(calc_x_offset "$anchor" "$topology" "$profile_outputs" $((depth + 1)))
          self_w=$(calc_logical_width "$connector" "$topology" "$profile_outputs")
          awk "BEGIN { printf \"%.0f\", $anchor_x - $self_w }"
          return
        fi

        # Literal "X,Y" — parse X
        echo "$position" | cut -d',' -f1
      }

      # Resolve a position string for an output to an absolute "X,Y" pair.
      # Handles right-of-CONNECTOR, left-of-CONNECTOR, and literal "X,Y".
      calc_anchored_position() {
        local connector="$1"
        local topology="$2"
        local profile_outputs="$3"

        local x
        x=$(calc_x_offset "$connector" "$topology" "$profile_outputs" 0)
        echo "''${x},0"
      }

      # Apply a profile's output settings.
      #
      # kscreen-doctor aborts the entire batch on the first invalid arg
      # ("Output mode WxH@RR not found." -> nothing else is applied). To
      # localize failures, we build args per output and invoke
      # kscreen-doctor once per output. Any per-output non-zero return is
      # logged but does NOT prevent the remaining outputs from being
      # applied.
      apply_profile() {
        local profile_name="$1"
        local topology="$2"
        local profile_outputs
        profile_outputs=$(get_profile_outputs "$profile_name")

        local failed=()
        local fallback_modes=()

        # Helper: invoke kscreen-doctor for a single output's arg list.
        # Logs the command, captures non-zero into the `failed` array.
        # Args: <connector> <output_id> <arg1> [arg2 ...]
        apply_output_args() {
          local _conn="$1"; shift
          local _id="$1"; shift
          if [ "$#" -eq 0 ]; then
            return
          fi
          log "  Applying ($_conn id=$_id): kscreen-doctor $*"
          if ! kscreen-doctor "$@"; then
            log "  Warning: kscreen-doctor failed for $_conn (id=$_id)"
            failed+=("$_conn")
          fi
        }

        # Iterate over each output in the profile
        local connectors
        connectors=$(echo "$profile_outputs" | jq -r 'keys[]')

        for connector in $connectors; do
          # Check if this connector is physically connected
          local output_id
          output_id=$(echo "$topology" | jq -r --arg c "$connector" '.[$c].id // empty')
          if [ -z "$output_id" ]; then
            log "  $connector: not connected, skipping"
            continue
          fi

          local out_args=()

          # Check enable/disable
          local enabled
          enabled=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].enable')
          if [ "$enabled" = "false" ]; then
            out_args+=("output.$output_id.disable")
            log "  $connector (id=$output_id): disable"
            apply_output_args "$connector" "$output_id" "''${out_args[@]}"
            continue
          fi

          out_args+=("output.$output_id.enable")

          # Scale
          local scale
          scale=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].scale // empty')
          if [ -n "$scale" ]; then
            out_args+=("output.$output_id.scale.$scale")
          fi

          # Mode (resolution@refreshRate) -- validated against the output's
          # actual mode list. Falls back to closest rate or skips entirely
          # if the resolution itself is unavailable.
          local cfg_resolution
          cfg_resolution=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].resolution // empty')
          local refresh_rate
          refresh_rate=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].refreshRate // empty')
          if [ -n "$cfg_resolution" ] || [ -n "$refresh_rate" ]; then
            local mode_res
            mode_res="''${cfg_resolution:-$(echo "$topology" | jq -r --arg c "$connector" '.[$c].currentResolution // empty')}"
            if [ -n "$mode_res" ]; then
              local mode_str
              mode_str=$(pick_mode "$connector" "$topology" "$mode_res" "$refresh_rate")
              if [ -n "$mode_str" ]; then
                out_args+=("output.$output_id.mode.''${mode_str}")
                # Track outputs that ended up on a non-exact match for the summary line.
                if [ -n "$refresh_rate" ] && [ "$mode_str" != "''${mode_res}@''${refresh_rate}" ]; then
                  fallback_modes+=("$connector->$mode_str")
                fi
              fi
            fi
          fi

          # Orientation / rotation
          local orientation
          orientation=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].orientation // empty')
          if [ -n "$orientation" ]; then
            out_args+=("output.$output_id.rotation.$orientation")
          fi

          # Position
          local position
          position=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].position // empty')
          if [ -n "$position" ]; then
            local actual_pos
            if [[ "$position" == right-of-* ]] || [[ "$position" == left-of-* ]]; then
              actual_pos=$(calc_anchored_position "$connector" "$topology" "$profile_outputs")
            else
              actual_pos="$position"
            fi
            out_args+=("output.$output_id.position.$actual_pos")
          else
            # No explicit position -> reset to origin so previously-anchored
            # outputs don't keep stale x-offsets after a topology change.
            out_args+=("output.$output_id.position.0,0")
          fi

          # Brightness (best-effort) -- convert 0.0-1.0 to 0-100 for kscreen-doctor
          local brightness
          brightness=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].brightness // empty')
          if [ -n "$brightness" ]; then
            local brightness_pct
            brightness_pct=$(awk "BEGIN { printf \"%d\", $brightness * 100 }")
            out_args+=("output.$output_id.brightness.$brightness_pct")
          fi

          # Primary -- mark as the primary output (panel/launcher anchor).
          # Plasma 6 uses `priority.N` (N=1 = primary); the legacy
          # `output.<id>.primary` arg was deprecated upstream.
          local primary
          primary=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].primary // false')
          if [ "$primary" = "true" ]; then
            out_args+=("output.$output_id.priority.1")
          fi

          log "  $connector (id=$output_id): res=$cfg_resolution scale=$scale refresh=$refresh_rate orient=$orientation pos=$position bright=$brightness primary=$primary"
          apply_output_args "$connector" "$output_id" "''${out_args[@]}"
        done

        # Auto-arrange any connected outputs not mentioned in the profile:
        # enable them and place each one to the right of the rightmost
        # already-positioned output. Prevents stale positions when a
        # monitor is hot-plugged into a topology whose matched profile
        # doesn't reference that connector, while keeping the new screen
        # reachable instead of going dark.
        local rightmost_x=0
        local profile_connectors
        profile_connectors=$(echo "$profile_outputs" | jq -r 'keys[]')
        for pc in $profile_connectors; do
          # Skip profile outputs that aren't actually connected.
          local pc_id
          pc_id=$(echo "$topology" | jq -r --arg c "$pc" '.[$c].id // empty')
          if [ -z "$pc_id" ]; then
            continue
          fi
          # Skip profile outputs explicitly disabled in the profile.
          local pc_enabled
          pc_enabled=$(echo "$profile_outputs" | jq -r --arg c "$pc" '.[$c].enable')
          if [ "$pc_enabled" = "false" ]; then
            continue
          fi
          local pc_x pc_w pc_right
          pc_x=$(calc_x_offset "$pc" "$topology" "$profile_outputs" 0)
          pc_w=$(calc_logical_width "$pc" "$topology" "$profile_outputs")
          pc_right=$((pc_x + pc_w))
          if [ "$pc_right" -gt "$rightmost_x" ]; then
            rightmost_x="$pc_right"
          fi
        done

        local topo_connectors
        topo_connectors=$(echo "$topology" | jq -r 'keys[]')
        for tc in $topo_connectors; do
          local in_profile
          in_profile=$(echo "$profile_outputs" | jq --arg c "$tc" 'has($c)')
          if [ "$in_profile" = "false" ]; then
            local tc_id tc_res tc_w
            tc_id=$(echo "$topology" | jq -r --arg c "$tc" '.[$c].id')
            local tc_args=(
              "output.$tc_id.enable"
              "output.$tc_id.position.''${rightmost_x},0"
            )
            log "  $tc (id=$tc_id): not in profile, auto-placing at x=$rightmost_x"
            apply_output_args "$tc" "$tc_id" "''${tc_args[@]}"
            tc_res=$(echo "$topology" | jq -r --arg c "$tc" '.[$c].currentResolution // empty')
            if [ -n "$tc_res" ]; then
              tc_w=$(echo "$tc_res" | cut -d'x' -f1)
              rightmost_x=$((rightmost_x + tc_w))
            fi
          fi
        done

        # Summary lines for visibility in `systemctl --user status`.
        if [ "''${#fallback_modes[@]}" -gt 0 ]; then
          log "Note: outputs using fallback modes: ''${fallback_modes[*]}"
        fi
        if [ "''${#failed[@]}" -gt 0 ]; then
          log "Note: ''${#failed[@]} output(s) failed to apply: ''${failed[*]}"
        fi
      }

      # ── Main loop ─────────────────────────────────────────────────────

      # Hot-plug listener: subscribes to KScreen D-Bus signals and writes a
      # "kick" line to a FIFO whenever something happens. The main loop
      # blocks on `read -t` from the FIFO instead of plain sleep, so it
      # wakes immediately on hot-plug events and otherwise polls every
      # POLL_INTERVAL seconds as a safety net.
      HOTPLUG_FIFO=$(mktemp -u --tmpdir display-profiles-hotplug.XXXXXX)
      mkfifo "$HOTPLUG_FIFO"
      # Open the FIFO read+write in this process so `read` never sees EOF
      # when the listener restarts or briefly disconnects.
      exec 3<>"$HOTPLUG_FIFO"

      (
        # gdbus monitor exits on bus errors; restart it under a loop so
        # transient failures don't kill the listener.
        while true; do
          gdbus monitor --session --dest org.kde.KScreen 2>/dev/null \
            | while IFS= read -r _line; do
                echo "kick" >&3 2>/dev/null || true
              done
          sleep 2
        done
      ) &
      HOTPLUG_PID=$!

      cleanup() {
        kill "$HOTPLUG_PID" 2>/dev/null || true
        exec 3>&- || true
        rm -f "$HOTPLUG_FIFO"
      }
      trap cleanup EXIT INT TERM

      log "Starting display-profiles daemon (poll every ''${POLL_INTERVAL}s, hot-plug listener pid=$HOTPLUG_PID)"

      while true; do
        topology=$(get_topology)

        if [ "$topology" != "$LAST_TOPOLOGY" ]; then
          LAST_TOPOLOGY="$topology"
          log "Topology: $topology"

          # Find best matching profile
          best_profile=$(find_best_profile "$topology") || true

          if [ -n "$best_profile" ] && [ "$best_profile" != "$LAST_PROFILE" ]; then
            log "Topology changed — pre-settle match: $best_profile"
            log "Waiting 1.5s for KWin to settle..."
            sleep 1.5

            # Re-read topology after settle (KWin may have adjusted)
            topology=$(get_topology)
            LAST_TOPOLOGY="$topology"
            log "Topology (post-settle): $topology"

            # Re-evaluate with settled topology
            best_profile=$(find_best_profile "$topology") || true
            if [ -n "$best_profile" ] && [ "$best_profile" != "$LAST_PROFILE" ]; then
              log "Applying profile: $best_profile"
              apply_profile "$best_profile" "$topology" || log "Error: apply_profile failed for $best_profile"
              LAST_PROFILE="$best_profile"
            elif [ -z "$best_profile" ] && [ "$LAST_PROFILE" != "__none__" ]; then
              log "Post-settle: no profile matches, leaving KDE defaults"
              LAST_PROFILE="__none__"
            else
              log "Post-settle: profile unchanged, skipping apply"
            fi
          elif [ -z "$best_profile" ] && [ "$LAST_PROFILE" != "__none__" ]; then
            log "Topology changed — no matching profile, leaving KDE defaults"
            LAST_PROFILE="__none__"
          fi
        fi

        # Wait up to POLL_INTERVAL seconds, but wake immediately on hot-plug.
        # Drain any additional kicks queued during the work above so a flurry
        # of events collapses into a single re-poll on the next iteration.
        if read -r -t "$POLL_INTERVAL" _kick <&3; then
          while read -r -t 0.05 _drain <&3; do :; done
          log "Hot-plug event — immediate re-poll"
        fi
      done
    '';
  };
in

{
  options = {
    custom.hmDisplayProfiles.enable = lib.mkEnableOption "topology-based display auto-configuration service";

    custom.hmDisplayProfiles.pollInterval = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Seconds between topology polls.";
    };

    custom.hmDisplayProfiles.profiles = lib.mkOption {
      type = lib.types.attrsOf profileModule;
      default = { };
      description = ''
        Display profiles keyed by name. Each profile defines match
        criteria (connector → resolution) and per-output settings.
        The profile with the most matching outputs wins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (userSettings.desktopEnvironment or null) == "kde-plasma";
        message = "custom.hmDisplayProfiles requires KDE Plasma (set desktopEnvironment = \"kde-plasma\" in user-settings.nix)";
      }
    ];

    systemd.user.services.display-profiles = {
      Unit = {
        Description = "Display Profiles — topology-based auto-configuration";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${displayProfilesScript}/bin/display-profiles-daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
