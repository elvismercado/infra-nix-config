# Linux 7.x kernel series — specific 7.x major release branches
# https://kernel.org
#
# Allows selecting a specific Linux 7.x kernel release branch packaged by Nixpkgs
# (7.0, 7.1, or 7.2).
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/kernel/linux-7.nix ];
#   custom.sysNixLinux7Kernel.enable = true;
#   custom.sysNixLinux7Kernel.version = "7.1"; # "7.0", "7.1", or "7.2" (default)

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixLinux7Kernel;
in
{
  options = {
    custom.sysNixLinux7Kernel.enable = lib.mkEnableOption "Linux 7.x series kernel branch (7.0, 7.1, or 7.2)";
    custom.sysNixLinux7Kernel.version = lib.mkOption {
      type = lib.types.enum [
        "7.0"
        "7.1"
        "7.2"
      ];
      default = "7.1";
      description = "Linux 7.x release branch version";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = lib.mkDefault (
      if cfg.version == "7.0" then
        pkgs.linuxPackages_7_0
      else if cfg.version == "7.1" then
        pkgs.linuxPackages_7_1
      else
        pkgs.linuxPackages_7_2
    );

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
