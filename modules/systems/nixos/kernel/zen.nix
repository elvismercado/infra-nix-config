# Linux Zen kernel — desktop-optimised kernel
# https://github.com/zen-kernel/zen-kernel
#
# The Zen kernel is tuned for interactive desktop workloads:
#   - 1000 Hz tick rate (vs. 300 Hz default) — lower input/scheduling latency
#   - Desktop-tuned CFS scheduler presets
#   - Voluntary kernel preemption for responsiveness
#   - Tunings for interactive desktop responsiveness and gaming
#
# Recommended for desktop, workstation, and laptop systems where interactivity
# matters more than raw batch throughput.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/kernel/zen.nix ];
#   custom.sysNixZenKernel.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

{
  options = {
    custom.sysNixZenKernel.enable = lib.mkEnableOption "Linux Zen kernel (desktop-optimised scheduler and tunings)";
  };

  config = lib.mkIf config.custom.sysNixZenKernel.enable {
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;

    assertions = [
      {
        assertion = !(
          config.custom.sysNixZenKernel.enable
          && (
            (config.custom.sysNixLatestKernel.enable or false)
            || (config.custom.sysNixXanmodKernel.enable or false)
            || (config.custom.sysNixLiquorixKernel.enable or false)
          )
        );
        message = "Cannot enable multiple custom kernel modules simultaneously.";
      }
    ];
  };
}
