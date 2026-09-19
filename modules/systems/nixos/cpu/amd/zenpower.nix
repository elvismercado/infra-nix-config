# AMD Zenpower — enhanced CPU sensor driver for Zen CPUs
# https://git.exozy.me/a/zenpower3
#
# Replaces the default k10temp kernel module with zenpower, which exposes
# significantly more sensor data on Zen CPUs:
#   - Per-CCD (chiplet) temperatures
#   - SoC power consumption
#   - Individual core voltages
#   - CPU package power (PPT)
#
# The standard k10temp driver only reports a single Tctl/Tdie temperature.
# Zenpower feeds all this data into lm_sensors, so tools like `sensors`,
# CoolerControl, and conky can display detailed per-core thermals.
#
# k10temp must be blacklisted because both drivers try to claim the same
# hardware — they cannot coexist.
#
# Supported: Zen (Ryzen 1000), Zen+ (2000), Zen 2 (3000), Zen 3 (5000), Zen 4 (7000)
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/cpu/amd/zenpower.nix ];
#   custom.sysNixAmdZenpower.enable = true;

{
  config,
  lib,
  ...
}:

{
  imports = [
    ./base.nix # base AMD CPU support (microcode updates)
  ];

  options = {
    custom.sysNixAmdZenpower.enable = lib.mkEnableOption "Zenpower sensor driver for full AMD Ryzen telemetry (replaces k10temp)";
  };

  config = lib.mkIf config.custom.sysNixAmdZenpower.enable {
    # Auto-enable the base AMD CPU module
    custom.sysNixAmdCpu.enable = true;

    # Blacklist k10temp — it conflicts with zenpower as both try to bind
    # to the same PCI device. k10temp only reports basic Tctl/Tdie temps.
    boot.blacklistedKernelModules = [ "k10temp" ];

    # Build and install the zenpower out-of-tree kernel module.
    # Must match the running kernel version (handled automatically by
    # config.boot.kernelPackages).
    boot.extraModulePackages = [
      config.boot.kernelPackages.zenpower
    ];

    # Load the zenpower module at boot so sensor data is available immediately.
    # After reboot, `sensors` will show zenpower entries instead of k10temp.
    boot.kernelModules = [ "zenpower" ];
  };
}
