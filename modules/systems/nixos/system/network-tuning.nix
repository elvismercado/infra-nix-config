# Network & I/O tuning — sysctl and service optimisations
#
# A collection of kernel tunables that improve network throughput,
# reduce latency, and prevent resource-limit issues on desktop systems:
#
#   - TCP congestion control — BBR by default for general workloads;
#     gaming hosts can opt into cubic to avoid the BBR ↔ Akamai/Steam
#     pacing collapse (see `congestionControl` option).
#   - qdisc — paired automatically with the congestion algorithm
#     (fq for BBR, fq_codel for cubic).
#   - irqbalance — distributes hardware interrupts across all CPU cores
#     instead of funnelling everything through core 0.
#
# Note: inotify max_user_watches is already set to 524288 by NixOS 25.11+
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/system/network-tuning.nix ];
#   custom.sysNixNetworkTuning.enable = true;
#
# Gaming hosts (e.g. FENNEC) should also set:
#   custom.sysNixNetworkTuning.congestionControl = "cubic";

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixNetworkTuning;
  qdiscFor = cc: if cc == "bbr" then "fq" else "fq_codel";
in
{
  options = {
    custom.sysNixNetworkTuning.enable = lib.mkEnableOption "network and I/O sysctl tuning";

    custom.sysNixNetworkTuning.congestionControl = lib.mkOption {
      type = lib.types.enum [ "bbr" "cubic" ];
      default = "bbr";
      description = ''
        TCP congestion control algorithm.

        - "bbr" (default): Google's BBR. Higher throughput and lower
          latency for general-purpose desktop, dev, and VPN workloads.
          Recommended for non-gaming hosts.

        - "cubic": Linux's traditional default. Use this on hosts that
          do heavy downloads from Steam / Akamai-fronted CDNs. BBR is
          known to collapse to ~10–20% of line speed in single-flow
          Steam downloads because Akamai's pacing interacts badly with
          BBR's bandwidth-probing behaviour. cubic restores full
          bandwidth (verified on FENNEC: 1 Gbps line went from
          ~150 Mbps under BBR to line-rate under cubic).

        The qdisc is selected to match: fq for BBR, fq_codel for cubic.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # --- TCP congestion control + matching qdisc ---
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = lib.mkDefault (qdiscFor cfg.congestionControl);
      "net.ipv4.tcp_congestion_control" = lib.mkDefault cfg.congestionControl;
    };

    # --- IRQ balancing ---
    # Distributes hardware interrupts (NVMe, GPU, NIC, USB) across
    # all available CPU cores. Without this, all IRQs land on core 0
    # which can bottleneck I/O on multi-core systems.
    services.irqbalance.enable = lib.mkDefault true;
  };
}
