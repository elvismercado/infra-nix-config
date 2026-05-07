# Hibernation (suspend-to-disk) support
# https://wiki.archlinux.org/title/Hibernate
#
# Hibernation saves the entire contents of RAM to the swap partition
# and powers off the machine. On the next boot, the kernel reads the
# image back from swap and restores the system to its pre-hibernation
# state — all open applications, documents, and sessions intact.
#
# Requirements:
#   - A physical swap partition (NOT zram — zram is RAM-backed)
#   - Swap size ≥ RAM for reliable hibernation (≥ RAM × 1.5 ideal)
#   - The swap partition must be declared in swapDevices (hardware-configuration.nix)
#
# zram interaction:
#   zram swap is ignored during hibernation — the kernel only writes
#   the hibernate image to the physical (disk-backed) swap device.
#   Both coexist safely.
#
# The resume device is auto-derived from swapDevices — the first
# physical (non-zram, non-random-encryption) swap partition is used.
# Override with custom.sysNixHibernate.resumeDevice if needed (e.g. swap files).
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/memory/hibernation.nix ];
#   custom.sysNixHibernate.enable = true;

{
  config,
  lib,
  ...
}:

let
  # Filter swapDevices to only physical swap partitions — exclude zram
  # (RAM-backed) and random-encryption (key lost on reboot). This matches
  # the filtering NixOS itself does in stage-1.nix for resume candidates.
  physicalSwap = builtins.filter (
    sd:
    lib.hasPrefix "/dev/" sd.device
    && !sd.randomEncryption.enable
    && !(lib.hasPrefix "/dev/zram" sd.device)
  ) config.swapDevices;

  # Auto-derived resume device: first physical swap partition, or null.
  autoResumeDevice = if physicalSwap != [ ] then (builtins.head physicalSwap).device else null;

  # Use explicit override if provided, otherwise auto-derived value.
  effectiveResumeDevice =
    if config.custom.sysNixHibernate.resumeDevice != null then
      config.custom.sysNixHibernate.resumeDevice
    else
      autoResumeDevice;
in
{
  options = {
    custom.sysNixHibernate.enable = lib.mkEnableOption "hibernation (suspend-to-disk) with auto-derived swap resume device";

    custom.sysNixHibernate.resumeDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to the swap device used for hibernation resume
        (e.g. /dev/disk/by-uuid/...). If null (default), the first
        physical swap partition from swapDevices is used automatically.
      '';
    };
  };

  config = lib.mkIf (config.custom.sysNixHibernate.enable && effectiveResumeDevice != null) {
    # Tell the kernel where to find the hibernation image on boot.
    # Without this, the kernel writes the image to swap on hibernate
    # but has no idea where to read it back on the next boot.
    boot.resumeDevice = effectiveResumeDevice;
  };
}
