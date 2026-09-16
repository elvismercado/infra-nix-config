# AMD Ryzen 9 3900X — CPU profile
# Zen 2 · 12 cores / 24 threads · 3.8 GHz base / 4.6 GHz boost · 105 W TDP
# https://www.amd.com/en/products/processors/amd-ryzen-9-3900x
#
# This is a convenience profile that imports and enables all relevant AMD
# modules for this CPU. Import this single file in your host config instead
# of importing each module individually.
#
# Enables:
#   - base.nix            — AMD microcode updates
#   - ryzen.nix           — kvm-amd, SEV, SMU, lm_sensors, ryzen-monitor-ng
#   - pstate.nix          — AMD P-State EPP frequency scaling (active mode)
#   - zenpower.nix        — Zenpower sensor driver (replaces k10temp)
#   - mitigations-off.nix — disable CPU vulnerability mitigations (single-user desktop)
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/cpu/amd/ryzen_9_3900x.nix ];
#   custom.sysNixAmdRyzen93900x.enable = true;

{
  config,
  lib,
  ...
}:

{
  imports = [
    ./ryzen.nix
    ./pstate.nix
    ./zenpower.nix
    ./zen-kernel.nix
    ./mitigations-off.nix
  ];

  options = {
    custom.sysNixAmdRyzen93900x.enable = lib.mkEnableOption "AMD Ryzen 9 3900X profile bundle (ryzen + pstate + zenpower + mitigations-off)";
  };

  config = lib.mkIf config.custom.sysNixAmdRyzen93900x.enable {
    custom.sysNixAmdRyzenCpu.enable = true;
    custom.sysNixAmdPstate.enable = true;
    custom.sysNixAmdZenpower.enable = true;
    custom.sysNixCpuMitigationsOff.enable = true;
  };
}
