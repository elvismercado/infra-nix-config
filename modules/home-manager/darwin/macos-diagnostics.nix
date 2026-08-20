# macOS diagnostics bundle — privacy-conscious support reports on the Desktop.
#
# Installs `macos-diagnostics` and a trusted Desktop launcher. Each run gathers
# system, network, disk, process, and crash diagnostics in a private temporary
# directory, redacts identifying values, then publishes a timestamped report and
# archive under ~/Desktop/macOS Diagnostics.
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/macos-diagnostics.nix ];
#   custom.hmMacosDiagnostics.enable = true;
#   custom.hmMacosDiagnostics.retention = 5;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmMacosDiagnostics;

  redactor = pkgs.writeTextFile {
    name = "macos-diagnostics-redact.py";
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
                ip_address(match.group("address"))
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
      system=MacBookPro18,3
      endpoints=203.0.113.42:443 http://[2001:db8::1]:8443
      rust=foo_daemon::version bar_core::firewall
      LogID: 9e0030d89ac03cc5955a56dbb589b93842bf9003ecaca8f2c4694480b2c3a199
      active login: elvismercado@github
      SearchDomains:[tail4cd86c.ts.net. example.com.]
      profile=profile-26fa disco key = d:a5110283fa8eec24 n=[Sx0EG] stable=npst1AW27R11CNTRL
      RegisterReq: onode= node=[Ab12C]
      suggested exit node: opnsense (npst1AW27R11CNTRL)
      suggested exit node: no preferred DERP, try again later
      disk=/dev/disk1s1
      EOF
      ${pkgs.python3}/bin/python "$target" "$test_dir" jin JIN /Users/jin

      if ${pkgs.gnugrep}/bin/grep -Eiq '203\.0\.113\.42|2001:db8|elvismercado@github|tail4cd86c|example\.com|profile-26fa|a5110283|Sx0EG|Ab12C|npst1AW27R11CNTRL|9e0030d8|opnsense' "$test_dir/sample.txt"; then
        echo "redactor behavior check failed: sensitive fixture value remains" >&2
        exit 1
      fi
      ${pkgs.gnugrep}/bin/grep -Fq 'system=MacBookPro18,3' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'disk=/dev/disk1s1' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'suggested exit node: <TAILSCALE_NODE-1>' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'suggested exit node: no preferred DERP, try again later' "$test_dir/sample.txt"
      ${pkgs.gnugrep}/bin/grep -Fq 'foo_daemon::version bar_core::firewall' "$test_dir/sample.txt"
    '';
  };

  diagnostics = pkgs.writeShellApplication {
    name = "macos-diagnostics";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gzip
      pkgs.python3
      pkgs.xdg-utils
    ];
    text = ''
      set -euo pipefail
      umask 077

      OUTPUT_DIR="$HOME/Desktop/macOS Diagnostics"
      RUNS_DIR="$OUTPUT_DIR/runs"
      RETENTION=${toString cfg.retention}
      TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
      WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macos-diagnostics.XXXXXX")
      RUN_DIR="$RUNS_DIR/$TIMESTAMP"
      STATUS_FILE="$WORK_DIR/collection-status.txt"

      cleanup() {
        rm -rf "$WORK_DIR"
      }
      trap cleanup EXIT

      mkdir -p "$RUNS_DIR"
      mkdir -p "$RUN_DIR"
      printf 'Started: %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" > "$STATUS_FILE"

      collect() {
        local section="$1"
        local file="$2"
        shift 2
        printf '\n=== %s ===\n' "$section" > "$RUN_DIR/$file"
        if "$@" >> "$RUN_DIR/$file" 2>&1; then
          printf '%s | %s | ok\n' "$section" "$file" >> "$STATUS_FILE"
        else
          printf '%s | %s | failed\n' "$section" "$file" >> "$STATUS_FILE"
        fi
      }

      collect "System information" "system.txt" sw_vers
      collect "Hardware" "hardware.txt" system_profiler SPHardwareDataType
      collect "Network" "network.txt" ifconfig -a
      collect "Routes" "routes.txt" netstat -rn
      collect "DNS" "dns.txt" scutil --dns
      collect "Disk layout" "storage.txt" diskutil list
      collect "Processes" "processes.txt" ps -eo pid,ppid,comm,state,%cpu,%mem,command --no-headers
      collect "System logs" "logs.txt" log show --last 1h --style compact
      collect "Session and power lifecycle" "lifecycle.txt" bash -lc '
        echo "=== current user ==="
        id -un 2>/dev/null || true
        echo
        echo "=== login sessions ==="
        who 2>/dev/null || true
        echo
        echo "=== current power settings ==="
        pmset -g everything 2>/dev/null || true
        echo
        echo "=== launchd/system lifecycle summary ==="
        launchctl print system 2>/dev/null | grep -iE "login|session|sleep|power|launchd|user|gui" || true
        echo
        echo "=== recent power and session events ==="
        log show --last 48h --style compact 2>/dev/null | grep -iE "shutdown|restart|reboot|sleep|hibernate|wake|login|logout|session|launchd|power" || true
      '
      collect "Crash reports" "crashes.txt" ls /Library/Logs/DiagnosticReports 2>/dev/null || true
      collect "Bluetooth" "bluetooth.txt" system_profiler SPBluetoothDataType 2>/dev/null || true

      ${redactor} "$RUN_DIR" "$(id -un)" "$(hostname)" "$HOME"

      REPORT_PATH="$OUTPUT_DIR/latest-report.txt"
      BUNDLE_PATH="$OUTPUT_DIR/latest-bundle.tar.gz"
      { printf 'macOS Diagnostics Report\nGenerated: %s\nAutomated redaction was applied; manually review all contents before sharing.\n\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"; cat "$STATUS_FILE"; printf '\n'; for file in "$RUN_DIR"/*.txt; do [ -f "$file" ] || continue; printf '\n######################################################################\n# %s\n######################################################################\n\n' "$(basename "$file")"; cat "$file"; printf '\n'; done; } > "$REPORT_PATH"

      tar -czf "$BUNDLE_PATH" -C "$RUN_DIR" .

      old_run=$(ls -1dt "$RUNS_DIR"/* 2>/dev/null | head -n "$((RETENTION + 1))" | tail -n +$((RETENTION + 1)) || true)
      if [ -n "$old_run" ]; then
        rm -rf "$old_run"
      fi

      printf 'Diagnostics saved to: %s\n' "$RUN_DIR"
      printf 'Share after review: %s\n' "$BUNDLE_PATH"
    '';
  };
in
{
  options.custom.hmMacosDiagnostics = {
    enable = lib.mkEnableOption "macOS diagnostics bundle";
    retention = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "How many macOS diagnostics runs to keep on disk.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ diagnostics ];
  };
}
