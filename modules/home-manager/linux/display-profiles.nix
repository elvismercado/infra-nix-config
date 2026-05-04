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
        description = "Whether this output should be enabled. Set false to disable.";
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
        type = lib.types.nullOr (lib.types.enum [
          "normal"
          "left"
          "right"
          "inverted"
        ]);
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
            "right-of-CONNECTOR" — auto-calculated from that output's
              applied resolution and scale (x = width / scale, y = 0)
            "X,Y" — explicit pixel position (e.g. "1920,0")
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
          the last one applied wins. Default false leaves the primary
          flag untouched on this output.
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
    lib.mapAttrs (
      _name: profile: {
        match = profile.match;
        outputs = lib.mapAttrs (
          _connector: out: {
            inherit (out) enable;
            resolution = out.resolution;
            scale = out.scale;
            refreshRate = out.refreshRate;
            orientation = if out.orientation != null then orientationMap.${out.orientation} else null;
            brightness = out.brightness;
            position = out.position;
            primary = out.primary;
          }
        ) profile.outputs;
      }
    ) cfg.profiles
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
      # when a dual-mode monitor reconnects with the same EDID UUID).
      get_topology() {
        local raw
        raw=$(kscreen-doctor --outputs 2>/dev/null) || { echo "{}"; return; }

        # Step 1: Extract connector names, output IDs, and current mode from
        # kscreen-doctor. Outputs "connector|id|currentRes" per connected output.
        local parsed
        parsed=$(echo "$raw" | sed 's/\x1b\[[0-9;]*m//g' | awk '
          /^Output:/ {
            if (connector != "" && connected) {
              print connector "|" id "|" current_res
            }
            id = $2
            connector = $3
            connected = 0
            current_res = ""
          }
          /connected/ && !/disconnected/ {
            if (/^[[:space:]]+connected/) connected = 1
          }
          /Modes:/ || /^[[:space:]]+[0-9]+:[0-9]+x[0-9]+@/ {
            n = split($0, tokens, " ")
            for (i = 1; i <= n; i++) {
              if (tokens[i] ~ /^[0-9]+:/) {
                t = tokens[i]
                sub(/^[0-9]+:/, "", t)
                if (t ~ /\*/) {
                  ct = t
                  sub(/@.*/, "", ct)
                  current_res = ct
                }
              }
            }
          }
          END {
            if (connector != "" && connected) {
              print connector "|" id "|" current_res
            }
          }
        ')

        [ -z "$parsed" ] && { echo "{}"; return; }

        # Step 2: Build JSON with max resolution from DRM sysfs.
        # /sys/class/drm/card*-CONNECTOR/modes lists true hardware modes
        # (one "WxH" per line), bypassing KWin's mode-list caching.
        local json="{"
        local first=1
        while IFS='|' read -r connector id current_res; do
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

          [ "$first" -eq 0 ] && json+=","
          json+="\"''${connector}\":{\"id\":\"''${id}\",\"resolution\":\"''${max_res}\",\"currentResolution\":\"''${current_res}\"}"
          first=0
        done <<< "$parsed"
        json+="}"

        echo "$json"
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

      # Calculate position for "right-of-CONNECTOR" using current topology
      calc_right_of_position() {
        local ref_connector="$1"
        local topology="$2"
        local profile_outputs="$3"

        # Use configured resolution for the reference output, fall back to current
        local ref_res
        ref_res=$(echo "$profile_outputs" | jq -r --arg c "$ref_connector" '.[$c].resolution // empty')
        if [ -z "$ref_res" ]; then
          ref_res=$(echo "$topology" | jq -r --arg c "$ref_connector" '.[$c].currentResolution // empty')
        fi
        if [ -z "$ref_res" ]; then
          echo "0,0"
          return
        fi

        # Get width from resolution (WxH)
        local ref_width
        ref_width=$(echo "$ref_res" | cut -d'x' -f1)

        # Get the scale applied to the reference output (from the profile)
        local ref_scale
        ref_scale=$(echo "$profile_outputs" | jq -r --arg c "$ref_connector" '.[$c].scale // 1')

        # Calculate x position: width / scale (logical pixels)
        local x_pos
        x_pos=$(awk "BEGIN { printf \"%d\", $ref_width / $ref_scale }")

        echo "''${x_pos},0"
      }

      # Apply a profile's output settings
      apply_profile() {
        local profile_name="$1"
        local topology="$2"
        local profile_outputs
        profile_outputs=$(get_profile_outputs "$profile_name")

        local args=()

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

          # Check enable/disable
          local enabled
          enabled=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].enable')
          if [ "$enabled" = "false" ]; then
            args+=("output.$output_id.disable")
            log "  $connector (id=$output_id): disable"
            continue
          fi

          args+=("output.$output_id.enable")

          # Scale
          local scale
          scale=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].scale // empty')
          if [ -n "$scale" ]; then
            args+=("output.$output_id.scale.$scale")
          fi

          # Mode (resolution@refreshRate)
          local cfg_resolution
          cfg_resolution=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].resolution // empty')
          local refresh_rate
          refresh_rate=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].refreshRate // empty')
          if [ -n "$cfg_resolution" ] || [ -n "$refresh_rate" ]; then
            # Use configured resolution, fall back to current
            local mode_res
            mode_res="''${cfg_resolution:-$(echo "$topology" | jq -r --arg c "$connector" '.[$c].currentResolution // empty')}"
            local mode_rate="''${refresh_rate}"
            if [ -n "$mode_res" ] && [ -n "$mode_rate" ]; then
              args+=("output.$output_id.mode.''${mode_res}@''${mode_rate}")
            elif [ -n "$mode_res" ]; then
              args+=("output.$output_id.mode.''${mode_res}")
            fi
          fi

          # Orientation / rotation
          local orientation
          orientation=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].orientation // empty')
          if [ -n "$orientation" ]; then
            args+=("output.$output_id.rotation.$orientation")
          fi

          # Position
          local position
          position=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].position // empty')
          if [ -n "$position" ]; then
            local actual_pos
            if [[ "$position" == right-of-* ]]; then
              local ref_conn="''${position#right-of-}"
              actual_pos=$(calc_right_of_position "$ref_conn" "$topology" "$profile_outputs")
            else
              actual_pos="$position"
            fi
            args+=("output.$output_id.position.$actual_pos")
          fi

          # Brightness (best-effort) — convert 0.0-1.0 to 0-100 for kscreen-doctor
          local brightness
          brightness=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].brightness // empty')
          if [ -n "$brightness" ]; then
            local brightness_pct
            brightness_pct=$(awk "BEGIN { printf \"%d\", $brightness * 100 }")
            args+=("output.$output_id.brightness.$brightness_pct")
          fi

          # Primary — mark as the primary output (panel/launcher anchor)
          local primary
          primary=$(echo "$profile_outputs" | jq -r --arg c "$connector" '.[$c].primary // false')
          if [ "$primary" = "true" ]; then
            args+=("output.$output_id.primary")
          fi

          log "  $connector (id=$output_id): res=$cfg_resolution scale=$scale refresh=$refresh_rate orient=$orientation pos=$position bright=$brightness primary=$primary"
        done

        if [ ''${#args[@]} -gt 0 ]; then
          log "Applying: kscreen-doctor ''${args[*]}"
          kscreen-doctor "''${args[@]}" || log "Warning: kscreen-doctor returned non-zero"
        fi
      }

      # ── Main loop ─────────────────────────────────────────────────────

      log "Starting display-profiles daemon (poll every ''${POLL_INTERVAL}s)"

      while true; do
        topology=$(get_topology)

        if [ "$topology" != "$LAST_TOPOLOGY" ]; then
          LAST_TOPOLOGY="$topology"

          # Find best matching profile
          best_profile=$(find_best_profile "$topology") || true

          if [ -n "$best_profile" ] && [ "$best_profile" != "$LAST_PROFILE" ]; then
            log "Topology changed — pre-settle match: $best_profile"
            log "Waiting 1.5s for KWin to settle..."
            sleep 1.5

            # Re-read topology after settle (KWin may have adjusted)
            topology=$(get_topology)
            LAST_TOPOLOGY="$topology"

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
            log "Current topology: $topology"
            LAST_PROFILE="__none__"
          fi
        fi

        sleep "$POLL_INTERVAL"
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
