# NixOS diagnostics bundle — privacy-conscious support reports on the Desktop.
#
# Installs `nixos-diagnostics` and a trusted Desktop launcher. Each run gathers
# system, Nix, hardware, network, service, journal, and Plasma diagnostics in a
# private temporary directory, redacts identifying values, then publishes a
# timestamped report and archive under ~/Desktop/NixOS Diagnostics.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/nixos-diagnostics.nix ];
#   custom.hmNixosDiagnostics.enable = true;
#   custom.hmNixosDiagnostics.retention = 5;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.hmNixosDiagnostics;
  publicRepo = "${config.home.homeDirectory}/${userSettings.repoPath}";

  redactor = pkgs.writeTextFile {
    name = "nixos-diagnostics-redact.py";
    text = ''
    from ipaddress import ip_address
    import pathlib
    import re
    import sys

    root = pathlib.Path(sys.argv[1])
    username = sys.argv[2]
    hostname = sys.argv[3]
    home = sys.argv[4]

    replacements = {}
    counts = {}

    def placeholder(kind, value):
        key = (kind, value.lower())
        if key not in replacements:
            counts[kind] = counts.get(kind, 0) + 1
            replacements[key] = "<{}-{}>".format(kind, counts[kind])
        return replacements[key]

    def replace_pattern(text, pattern, kind, flags=0):
        regex = re.compile(pattern, flags)
        return regex.sub(lambda match: placeholder(kind, match.group(0)), text)

    def replace_ips(text):
      ipv4_candidates = re.compile(
        r"(?<![A-Za-z0-9_.])(?P<address>(?:\d{1,3}\.){3}\d{1,3})(?P<port>:\d{1,5})?(?![A-Za-z0-9_.])"
      )
      bracketed_ipv6_candidates = re.compile(
        r"\[(?P<address>[0-9A-Fa-f:]+)\](?P<port>:\d{1,5})?"
      )
      bare_ipv6_candidates = re.compile(
        r"(?<![A-Za-z0-9_:])(?=[0-9A-Fa-f:]*:[0-9A-Fa-f:]*)(?P<address>[0-9A-Fa-f:]{2,})(?![A-Za-z0-9_:])"
      )

      def redact_candidate(match, kind):
        try:
          parsed_address = ip_address(match.group("address"))
        except ValueError:
          return match.group(0)
        suffix = "_ENDPOINT" if match.groupdict().get("port") else ""
        return placeholder(kind + suffix, match.group(0))

      text = ipv4_candidates.sub(lambda match: redact_candidate(match, "IPV4"), text)
      text = bracketed_ipv6_candidates.sub(lambda match: redact_candidate(match, "IPV6"), text)
      return bare_ipv6_candidates.sub(lambda match: redact_candidate(match, "IPV6"), text)

    def sanitize(text):
        if home:
            text = text.replace(home, "<HOME>")

        text = replace_pattern(
          text,
          r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
          "EMAIL",
        )
        if username:
          text = re.sub(
            r"(?<![A-Za-z0-9_]){}(?![A-Za-z0-9_])".format(re.escape(username)),
            "<USER>",
            text,
            flags=re.IGNORECASE,
          )
        if hostname:
          text = re.sub(
            r"(?<![A-Za-z0-9_]){}(?![A-Za-z0-9_])".format(re.escape(hostname)),
            "<HOST>",
            text,
            flags=re.IGNORECASE,
          )

        text = replace_pattern(text, r"\b[A-Fa-f0-9]{2}(?::[A-Fa-f0-9]{2}){5}\b", "MAC")
        text = replace_pattern(text, r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[1-5][0-9A-Fa-f]{3}-[89ABab][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}\b", "UUID")
        text = replace_pattern(text, r"\b(?:github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9]+|tskey-[A-Za-z0-9_-]+)\b", "TOKEN")
        text = replace_pattern(text, r"(?i)(?<=authorization: bearer )[A-Za-z0-9._~+/=-]+", "TOKEN")
        text = replace_pattern(text, r"\b\d{16}\b", "ACCOUNT")
        text = replace_pattern(text, r"\b[A-Za-z0-9._%+-]+@github\b", "TAILSCALE_ACCOUNT", re.IGNORECASE)
        text = replace_pattern(text, r"\b(?:[A-Za-z0-9-]+\.)+ts\.net\.?", "TAILNET", re.IGNORECASE)
        text = replace_pattern(text, r"\bprofile-[A-Za-z0-9_-]+\b", "TAILSCALE_PROFILE", re.IGNORECASE)
        text = replace_pattern(text, r"\bnp[A-Za-z0-9]{8,}\b", "TAILSCALE_ID", re.IGNORECASE)
        text = re.sub(
            r"(?i)(\b(?:SearchDomains|LocalDomains):)\[[^\]]*\]",
            lambda match: match.group(1) + "[<DNS-DOMAINS>]",
            text,
        )
        text = re.sub(
            r"(?i)(\b(?:LogID|be):\s*)[0-9a-f]{32,64}",
            lambda match: match.group(1) + placeholder("TAILSCALE_ID", match.group(0)),
            text,
        )
        text = re.sub(
            r"(?i)(\b(?:n|node|onode)=\s*)\[[A-Za-z0-9+/=_-]+\]",
            lambda match: match.group(1) + placeholder("TAILSCALE_KEY", match.group(0)),
            text,
        )
        text = re.sub(
          r"(?im)(\bsuggested exit node:)(?!\s*no preferred DERP\b)(\s*)([^\r\n(,]+?)(?=\s*(?:\(|,|$))",
          lambda match: match.group(1) + match.group(2) + placeholder("TAILSCALE_NODE", match.group(3)),
          text,
        )
        text = re.sub(
          r"(?i)(\b(?:disco key|ts2021|legacy)\s*(?:=|:)\s*)(?:d:)?(?:\[[^\]]+\]|[A-Za-z0-9+/=_-]+)",
          lambda match: match.group(1) + placeholder("TAILSCALE_KEY", match.group(0)),
          text,
        )
        text = replace_pattern(
          text,
          r"(?i)\bdev-disk-by(?:\\x2d|-)[^\s]+",
          "DISK_ID",
        )
        text = re.sub(
            r"(?i)(\bssid(?:=|:|\s+))(\"[^\"]*\"|'[^']*'|[^\s,;]+)",
            lambda match: match.group(1) + placeholder("SSID", match.group(2)),
            text,
        )
        return replace_ips(text)

    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if b"\x00" in data:
            raise RuntimeError("refusing to publish binary diagnostic file: {}".format(path))
        path.write_text(sanitize(data.decode("utf-8", errors="replace")), encoding="utf-8")

    summary = root / "redaction-summary.txt"
    lines = ["Redacted values by category:"]
    lines.extend("{}: {}".format(kind, counts[kind]) for kind in sorted(counts))
    if len(lines) == 1:
        lines.append("None detected")
    summary.write_text(
      "\n".join(lines) + "\n",
      encoding="utf-8",
    )
    '';
    checkPhase = ''
      ${pkgs.python3}/bin/python -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_text(), sys.argv[1], "exec")' "$target"

      test_dir=$(${pkgs.coreutils}/bin/mktemp -d)
      trap '${pkgs.coreutils}/bin/rm -rf "$test_dir"' EXIT
      ${pkgs.coreutils}/bin/cat > "$test_dir/sample.txt" <<'EOF'
      system=/nix/store/example-nixos-system-JIN
      endpoints=84.86.154.95:19468 http://[fd7a:115c:a1e0::1]:46143
      rust=mullvad_daemon::version talpid_core::firewall
      LogID: 9e0030d89ac03cc5955a56dbb589b93842bf9003ecaca8f2c4694480b2c3a199
      active login: elvismercado@github
      SearchDomains:[tail4cd86c.ts.net. lajuve.eu.]
      profile=profile-26fa disco key = d:a5110283fa8eec24 n=[Sx0EG] stable=npst1AW27R11CNTRL
      RegisterReq: onode= node=[Ab12C]
      suggested exit node: opnsense (npst1AW27R11CNTRL)
      suggested exit node: no preferred DERP, try again later
      disk=dev-disk-by\x2did-nvme\x2dCT1000P2SSD8_2116E59827C8\x2dpart1.device
      partition=dev-disk-by\x2duuid-EB42\x2d9540.device
      EOF
      ${pkgs.python3}/bin/python "$target" "$test_dir" jin JIN /home/jin

      if ${pkgs.gnugrep}/bin/grep -Eiq 'JIN|84\.86\.154\.95|fd7a:115c|elvismercado@github|tail4cd86c|lajuve\.eu|profile-26fa|a5110283|Sx0EG|Ab12C|npst1AW27R11CNTRL|9e0030d8|opnsense|CT1000P2SSD8|2116E59827C8|EB42|9540' "$test_dir/sample.txt"; then
        echo "redactor behavior check failed: sensitive fixture value remains" >&2
        exit 1
      fi
      ${pkgs.gnugrep}/bin/grep -Fq 'suggested exit node: <TAILSCALE_NODE-1>' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'suggested exit node: no preferred DERP, try again later' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'mullvad_daemon::version talpid_core::firewall' "$test_dir/sample.txt"
    '';
  };

  diagnostics = pkgs.writeShellApplication {
    name = "nixos-diagnostics";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gnutar
      pkgs.gzip
      pkgs.iproute2
      pkgs.jq
      pkgs.kdePackages.libkscreen
      pkgs.libnotify
      pkgs.networkmanager
      pkgs.nix
      pkgs.pciutils
      pkgs.procps
      pkgs.python3
      pkgs.systemd
      pkgs.usbutils
      pkgs.util-linux
      pkgs.xdg-utils
    ];
    text = ''
      set -euo pipefail
      umask 077

      OUTPUT_DIR="$HOME/Desktop/NixOS Diagnostics"
      RUNS_DIR="$OUTPUT_DIR/runs"
      RETENTION=${toString cfg.retention}
      PUBLIC_REPO=${lib.escapeShellArg publicRepo}
      TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
      WORK_DIR=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/nixos-diagnostics.XXXXXX")
      RUN_DIR="$RUNS_DIR/$TIMESTAMP"
      STATUS_FILE="$WORK_DIR/collection-status.txt"
      INTERACTIVE=false

      cleanup() {
        rm -rf "$WORK_DIR"
      }
      trap cleanup EXIT

      for argument in "$@"; do
        case "$argument" in
          --interactive) INTERACTIVE=true ;;
          *) echo "Unknown argument: $argument" >&2; exit 2 ;;
        esac
      done

      mkdir -p "$RUNS_DIR"
      exec 9>"$OUTPUT_DIR/.collection.lock"
      if ! flock -n 9; then
        echo "A diagnostics collection is already running." >&2
        exit 1
      fi

      printf 'Started: %s\n' "$(date --iso-8601=seconds)" > "$STATUS_FILE"

      collect() {
        local section="$1"
        local file="$2"
        shift 2
        printf '\n=== %s ===\n' "$section" > "$WORK_DIR/$file"
        if "$@" >> "$WORK_DIR/$file" 2>&1; then
          printf '%s | %s | ok\n' "$section" "$file" >> "$STATUS_FILE"
        else
          local status=$?
          printf '%s | %s | exit %s\n' "$section" "$file" "$status" >> "$STATUS_FILE"
          printf '\n[collector exited with status %s]\n' "$status" >> "$WORK_DIR/$file"
        fi
      }

      collect_privileged() {
        local section="$1"
        local file="$2"
        shift 2
        if [ "$HAVE_SUDO" = true ]; then
          collect "$section" "$file" sudo -n "$@"
        else
          printf '\n=== %s ===\nSkipped: privileged access was unavailable.\n' "$section" > "$WORK_DIR/$file"
          printf '%s | %s | skipped (no sudo)\n' "$section" "$file" >> "$STATUS_FILE"
        fi
      }

      echo "NixOS diagnostics will collect system logs and hardware state."
      echo "Private application data, environment variables, histories, and secret files are excluded."
      HAVE_SUDO=false
      if command -v sudo >/dev/null 2>&1 && sudo -v; then
        HAVE_SUDO=true
      else
        echo "Continuing without privileged diagnostics."
      fi

      # Expanded by the child shell, not this script.
      # shellcheck disable=SC2016
      collect "System identity" system.txt bash -c '
        printf "Date: "; date --iso-8601=seconds
        printf "NixOS: "; nixos-version
        printf "Kernel: "; uname -srvmo
        printf "Boot ID: "; cat /proc/sys/kernel/random/boot_id
        printf "Uptime: "; uptime
        printf "Command line: "; cat /proc/cmdline
        loginctl show-session "''${XDG_SESSION_ID:-self}" -p Type -p Class -p State -p Remote -p Desktop 2>/dev/null || true
      '

      # Expanded by the child shell, not this script.
      # shellcheck disable=SC2016
      collect "Nix and repository" nix.txt bash -c '
        nix --version
        printf "Current system: "; readlink -f /run/current-system
        nixos-rebuild list-generations --no-build-nix 2>/dev/null | tail -10 || true
        if [ -d "$1/.git" ]; then
          printf "\nRepository revision: "; git -C "$1" rev-parse HEAD
          printf "\nDirty paths:\n"; git -C "$1" status --short
          printf "\nFlake revisions:\n"
          nix flake metadata --json "$1" 2>/dev/null | jq "{revision, dirtyRevision, inputs: (.locks.nodes | with_entries(.value |= {locked: (.locked // {} | {type, rev, lastModified})}))}" || true
        else
          echo "Public repository not found."
        fi
      ' _ "$PUBLIC_REPO"

      collect "CPU and memory" hardware.txt bash -c '
        lscpu
        printf "\nMemory:\n"; free -h
        printf "\nSwap:\n"; swapon --show
        printf "\nPCI devices:\n"; lspci -nnk
        printf "\nUSB devices:\n"; lsusb
      '

      collect "Storage and filesystems" storage.txt bash -c '
        lsblk -o NAME,TYPE,SIZE,FSTYPE,FSVER,MOUNTPOINTS,MODEL
        printf "\nMounts:\n"; findmnt --real
        printf "\nUsage:\n"; df -hT
      '

      collect "Network state" network.txt bash -c '
        nmcli -f DEVICE,TYPE,STATE device status
        printf "\nAddresses:\n"; ip -brief address
        printf "\nRoutes:\n"; ip route show table all
        printf "\nRules:\n"; ip rule
        printf "\nResolver:\n"; resolvectl status
        printf "\n/etc/resolv.conf target:\n"; readlink -f /etc/resolv.conf
        if command -v mullvad >/dev/null 2>&1; then
          printf "\nMullvad:\n"
          mullvad status | sed -n "1p"
        fi
        if command -v tailscale >/dev/null 2>&1; then
          printf "\nTailscale (identity fields excluded):\n"
          tailscale status --json | jq "{BackendState, Health, Self: {Online: .Self.Online, Active: .Self.Active, ExitNode: .Self.ExitNode, ExitNodeOption: .Self.ExitNodeOption, TailscaleIPs: .Self.TailscaleIPs}, Peers: [.Peer[]? | {Online, Active, ExitNode, ExitNodeOption, TailscaleIPs}]}"
        fi
      '

      collect "Failed system services" services.txt systemctl --failed --no-pager --full
      collect "Failed user services" user-services.txt systemctl --user --failed --no-pager --full
      collect "Boot performance" boot.txt bash -c '
        systemd-analyze
        printf "\nCritical chain:\n"; systemd-analyze critical-chain
        printf "\nSlow units:\n"; systemd-analyze blame | head -40
      '

      collect "Current boot warnings" journal-current.txt journalctl -b -p warning..alert --no-pager -o short-iso-precise
      collect "Previous boot warnings" journal-previous.txt journalctl -b -1 -p warning..alert --no-pager -o short-iso-precise
      collect "User service errors" journal-user.txt journalctl --user -b -p err..alert --no-pager -o short-iso-precise
      collect "Network and VPN journal" journal-network.txt journalctl -b --no-pager -o short-iso-precise -u NetworkManager -u systemd-resolved -u mullvad-daemon -u tailscaled
      collect "Session and power lifecycle" lifecycle.txt bash -c '
        echo "=== Sessions ==="
        loginctl list-sessions || true
        echo
        echo "=== Users ==="
        loginctl list-users || true
        echo
        echo "=== Active system jobs ==="
        systemctl list-jobs --all --full --no-pager || true
        echo
        echo "=== Active user services ==="
        systemctl --user --no-pager list-units --type=service --state=running --all || true
        echo
        echo "=== This boot lifecycle events ==="
        journalctl -b --no-pager -o short-iso-precise -g "shutdown|reboot|restart|sleep|hibernate|suspend|resume|logind|user manager|user.slice|stop job|session|login|logout" || true
        echo
        echo "=== Previous boot lifecycle events ==="
        journalctl -b -1 --no-pager -o short-iso-precise -g "shutdown|reboot|restart|sleep|hibernate|suspend|resume|logind|user manager|user.slice|stop job|session|login|logout" || true
      '
      collect "Suspend and resume events" suspend-resume.txt bash -c 'journalctl -b --no-pager -o short-iso-precise | grep -iE "suspend|resume|sleep|hibernate|PM:" || true'
      collect "Recent crashes" crashes.txt coredumpctl list --since "7 days ago" --no-pager
      collect_privileged "Kernel warnings" kernel.txt journalctl -k -b -p warning..alert --no-pager -o short-iso-precise

      # Expanded by the child shell, not this script.
      # shellcheck disable=SC2016
      collect "Plasma and display" desktop.txt bash -c '
        plasmashell --version 2>/dev/null || true
        kwin_wayland --version 2>/dev/null || true
        kscreen-doctor --outputs 2>/dev/null || true
        printf "\nSession:\n"
        loginctl show-session "''${XDG_SESSION_ID:-self}" -p Type -p Class -p State -p Remote -p Desktop 2>/dev/null || true
      '

      printf 'Completed collection: %s\n' "$(date --iso-8601=seconds)" >> "$STATUS_FILE"

      python3 ${redactor} "$WORK_DIR" "$(id -un)" "$(cat /proc/sys/kernel/hostname)" "$HOME"

      REPORT="$WORK_DIR/report.txt"
      REPORT_TMP="$WORK_DIR/.report.txt.tmp"
      {
        echo "NixOS Diagnostics Report"
        echo "Generated: $(date --iso-8601=seconds)"
        echo "Automated redaction was applied; manually review all contents before sharing."
        for file in "$WORK_DIR"/*.txt; do
          [ "$file" = "$REPORT" ] && continue
          printf '\n\n######################################################################\n'
          printf '# %s\n' "$(basename "$file")"
          printf '######################################################################\n\n'
          cat "$file"
        done
      } > "$REPORT_TMP"
      mv "$REPORT_TMP" "$REPORT"

      mkdir "$RUN_DIR"
      cp -a "$WORK_DIR"/. "$RUN_DIR"/
      tar -C "$RUN_DIR" -czf "$OUTPUT_DIR/.bundle-$TIMESTAMP.tar.gz" --exclude=bundle.tar.gz .
      mv "$OUTPUT_DIR/.bundle-$TIMESTAMP.tar.gz" "$RUN_DIR/bundle.tar.gz"

      ln -s "runs/$TIMESTAMP/report.txt" "$OUTPUT_DIR/.latest-report.txt.new"
      mv -Tf "$OUTPUT_DIR/.latest-report.txt.new" "$OUTPUT_DIR/latest-report.txt"
      ln -s "runs/$TIMESTAMP/bundle.tar.gz" "$OUTPUT_DIR/.latest-bundle.tar.gz.new"
      mv -Tf "$OUTPUT_DIR/.latest-bundle.tar.gz.new" "$OUTPUT_DIR/latest-bundle.tar.gz"

      mapfile -t OLD_RUNS < <(find "$RUNS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | tail -n "+$((RETENTION + 1))")
      for old_run in "''${OLD_RUNS[@]}"; do
        rm -rf "$RUNS_DIR/''${old_run:?}"
      done

      echo
      echo "Diagnostics saved to: $RUN_DIR"
      echo "Share after review: $OUTPUT_DIR/latest-bundle.tar.gz"
      notify-send "NixOS diagnostics complete" "Sanitized report saved to the Desktop" 2>/dev/null || true
      xdg-open "$OUTPUT_DIR" >/dev/null 2>&1 || true

      if [ "$INTERACTIVE" = true ]; then
        echo
        read -r -p "Press Enter to close this window..." _ || true
      fi
    '';
  };

  readme = pkgs.writeText "nixos-diagnostics-readme.txt" ''
    NixOS Diagnostics
    =================

    Double-click "Run Diagnostics" or run `nixos-diagnostics` in a terminal.
    The collector may request sudo once. If declined, it still creates a report
    and marks privileged sections as skipped.

    Share either latest-report.txt or latest-bundle.tar.gz only after reviewing
    the contents. Reports are automatically redacted, but automated redaction
    cannot guarantee that every application-specific identifier is recognized.

    The latest ${toString cfg.retention} runs are retained under runs/.
  '';
in

{
  options.custom.hmNixosDiagnostics = {
    enable = lib.mkEnableOption "privacy-conscious NixOS diagnostics bundle with CLI and Desktop launcher";

    retention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of timestamped diagnostic runs retained on the Desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ diagnostics ];

    xdg.desktopEntries.nixos-diagnostics = {
      name = "Run NixOS Diagnostics";
      comment = "Create a sanitized system support bundle";
      exec = "${diagnostics}/bin/nixos-diagnostics --interactive";
      icon = "utilities-system-monitor";
      categories = [
        "System"
        "Utility"
      ];
      terminal = true;
    };

    home.file = {
      "Desktop/NixOS Diagnostics/Run Diagnostics.desktop" = {
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Run NixOS Diagnostics
          Comment=Create a sanitized system support bundle
          Exec=${diagnostics}/bin/nixos-diagnostics --interactive
          Icon=utilities-system-monitor
          Categories=System;Utility;
          Terminal=true
        '';
        executable = true;
      };

      "Desktop/NixOS Diagnostics/README.txt".source = readme;
    };
  };
}
