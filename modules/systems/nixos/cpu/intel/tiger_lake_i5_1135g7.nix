# Intel Core i5-1135G7 — CPU profile (Tiger Lake / 11th gen mobile)
# 4 cores / 8 threads · 2.4 GHz base / 4.2 GHz boost · 28 W TDP (configurable)
# https://www.intel.com/content/www/us/en/products/sku/208658/
#
# Convenience profile that imports and enables the Intel CPU base support
# for this processor. Import this single file in your host config instead
# of importing each module individually.
#
# Enables:
#   - base.nix — Intel microcode updates + kvm-intel
#
# No CPU-specific kernel parameters are required for stock Tiger Lake.
# intel_pstate is selected automatically by the kernel and works well
# with power-profiles-daemon out of the box.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/cpu/intel/tiger_lake_i5_1135g7.nix ];
#   custom.sysNixIntelTigerLakeI51135g7.enable = true;

{
  config,
  lib,
  ...
}:

{
  imports = [
    ./base.nix
  ];

  options = {
    custom.sysNixIntelTigerLakeI51135g7.enable = lib.mkEnableOption "Intel Core i5-1135G7 (Tiger Lake) profile (Intel CPU base + microcode + kvm-intel)";
  };

  config = lib.mkIf config.custom.sysNixIntelTigerLakeI51135g7.enable {
    custom.sysNixIntelCpu.enable = true;
  };
}
