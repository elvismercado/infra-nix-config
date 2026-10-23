# Linux XanMod kernel — desktop, gaming, and low-latency tuned kernel
# https://xanmod.org
#
# The XanMod kernel is tuned for responsiveness, high-throughput desktop use,
# and low-latency gaming:
#   - Custom PREEMPT scheduling with tweaked process latency
#   - BBRv3 TCP congestion control
#   - Custom memory management and virtual memory caching parameters
#   - Choice of LTS branch (best stability with out-of-tree drivers) or latest upstream
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/kernel/xanmod.nix ];
#   custom.sysNixXanmodKernel.enable = true;
#   custom.sysNixXanmodKernel.variant = "stable"; # "stable" (default), "latest", or "mainline"

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixXanmodKernel;
in
{
  options = {
    custom.sysNixXanmodKernel.enable = lib.mkEnableOption "Linux XanMod kernel with desktop/gaming latency tunings and BBRv3";
    custom.sysNixXanmodKernel.variant = lib.mkOption {
      type = lib.types.enum [
        "stable"
        "latest"
        "mainline"
      ];
      default = "stable";
      description = "XanMod kernel variant: 'stable' (pkgs.linuxPackages_xanmod_stable), 'latest' (pkgs.linuxPackages_xanmod_latest), or 'mainline' (pkgs.linuxPackages_xanmod)";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = lib.mkDefault (
      if cfg.variant == "stable" then
        pkgs.linuxPackages_xanmod_stable
      else if cfg.variant == "latest" then
        pkgs.linuxPackages_xanmod_latest
      else
        pkgs.linuxPackages_xanmod
    );

    assertions = [
      {
        assertion = !(
          cfg.enable
          && (
            (config.custom.sysNixZenKernel.enable or false)
            || (config.custom.sysNixLatestKernel.enable or false)
            || (config.custom.sysNixLinux7Kernel.enable or false)
          )
        );
        message = "Cannot enable multiple custom kernel modules simultaneously.";
      }
    ];
  };
}
