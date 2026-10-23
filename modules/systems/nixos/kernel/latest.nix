# Linux Latest kernel — latest upstream stable kernel release
# https://kernel.org
#
# Tracks the latest upstream stable Linux kernel packaged by Nixpkgs
# (pkgs.linuxPackages_latest).
#
# Recommended for hardware requiring the latest drivers, CPU/GPU feature
# support, or newer kernel capabilities.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/kernel/latest.nix ];
#   custom.sysNixLatestKernel.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

{
  options = {
    custom.sysNixLatestKernel.enable = lib.mkEnableOption "latest upstream stable Linux kernel release (pkgs.linuxPackages_latest)";
  };

  config = lib.mkIf config.custom.sysNixLatestKernel.enable {
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    assertions = [
      {
        assertion = !(config.custom.sysNixZenKernel.enable or false && config.custom.sysNixLatestKernel.enable);
        message = "Cannot enable both custom.sysNixZenKernel and custom.sysNixLatestKernel simultaneously.";
      }
    ];
  };
}
