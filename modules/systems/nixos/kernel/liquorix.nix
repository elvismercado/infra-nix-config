# Linux Liquorix kernel — low-latency multimedia and gaming kernel
# https://liquorix.net
#
# The Liquorix kernel is tuned for interactive desktop responsiveness and gaming:
#   - Zen-based voluntary preemption and 1000 Hz tick rate
#   - Budget Fair Queue (BFQ) storage I/O scheduler tuning
#   - High-performance network and virtual memory defaults
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/kernel/liquorix.nix ];
#   custom.sysNixLiquorixKernel.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixLiquorixKernel;
in
{
  options = {
    custom.sysNixLiquorixKernel.enable = lib.mkEnableOption "Linux Liquorix kernel with low-latency preemption and multimedia/gaming tunings";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_liquorix;

    assertions = [
      {
        assertion = !(
          cfg.enable
          && (
            (config.custom.sysNixZenKernel.enable or false)
            || (config.custom.sysNixLatestKernel.enable or false)
            || (config.custom.sysNixXanmodKernel.enable or false)
          )
        );
        message = "Cannot enable multiple custom kernel modules simultaneously.";
      }
    ];
  };
}
