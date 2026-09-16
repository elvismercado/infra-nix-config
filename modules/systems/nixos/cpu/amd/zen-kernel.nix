# Linux Zen kernel — desktop-optimised kernel for AMD CPUs
# https://github.com/zen-kernel/zen-kernel
#
# The Zen kernel is tuned for interactive desktop workloads:
#   - 1000 Hz tick rate (vs. 300 Hz default) — lower input/scheduling latency
#   - Desktop-tuned CFS scheduler presets
#   - Voluntary kernel preemption for responsiveness
#   - Latest AMD P-State and amdgpu driver back-ports
#
# Recommended for AMD desktop/workstation systems where interactivity
# matters more than raw throughput.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/cpu/amd/zen-kernel.nix ];
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
  };
}
