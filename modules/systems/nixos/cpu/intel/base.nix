# Intel CPU — base module for all Intel processors
# This is the foundation imported by Intel-specific profiles (e.g. tiger_lake_*).
# You typically don't enable this directly — it gets auto-enabled by the
# per-CPU profile that imports it.
#
# Enables:
#   - Microcode updates (security/stability errata applied at boot)
#   - kvm-intel kernel module (Intel VT-x for QEMU/KVM virtualisation)
#   - intel_pstate is the default scaling driver on Sandy Bridge+ — no need
#     to force it; the kernel selects it automatically. Set passive/active
#     mode in a per-CPU profile if a host needs it overridden.

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.sysNixIntelCpu.enable = lib.mkEnableOption "Intel CPU base support (microcode + kvm-intel) — typically auto-enabled by per-CPU profiles";
  };

  config = lib.mkIf config.custom.sysNixIntelCpu.enable {
    hardware.cpu.intel = {
      # Apply Intel CPU microcode updates at boot.
      # Microcode patches fix CPU-level bugs (Spectre/Meltdown/MDS class
      # vulnerabilities, stability errata). Loaded by the kernel before
      # userspace starts. Requires hardware.enableRedistributableFirmware
      # (enabled by default on NixOS).
      updateMicrocode = true;
    };

    # Load the kvm-intel kernel module — enables hardware-accelerated
    # virtualisation (Intel VT-x) for QEMU/KVM virtual machines. Without
    # this module, VMs fall back to slow software emulation.
    # Note: also typically set by nixos-generate-config in
    # hardware-configuration.nix, but we declare it here so the module is
    # self-contained. Duplicate entries are harmless (lists are merged).
    boot.kernelModules = [ "kvm-intel" ];
  };
}
