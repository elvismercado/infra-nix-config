# Lenovo ThinkPad T14 Gen 2 (Intel) — laptop chassis quirks
#
# Owns the things that are NOT CPU- or GPU-specific but are needed to
# make the T14 Gen 2 chassis behave correctly on Linux:
#
#   - acpi_backlight=native — force the kernel-native backlight interface
#     so the systemd backlight save/restore service can persist brightness
#     across reboots. Without this, brightness keys may work but state is
#     lost on shutdown.
#   - psmouse.synaptics_intertouch=0 — fixes the Synaptics touchpad on
#     some T14 units where pressing-to-click silently fails to register.
#   - hardware.trackpoint.enable + emulateWheel — standard ThinkPad TrackPoint
#     behaviour with middle-button-drag scrolling.
#
# Mirrors what nixos-hardware would provide via:
#   - lenovo/thinkpad/default.nix     (TrackPoint)
#   - lenovo/thinkpad/t14/default.nix (acpi_backlight + touchpad)
#
# CPU / GPU / power management / SSD trim are handled by separate modules
# (`cpu/intel/tiger_lake_i5_1135g7`, `graphics/intel_iris_xe`,
# `power/power-profiles-daemon`, `ssd`). This module is purely the
# chassis-level quirks layer.
#
# Suspend-to-RAM: in BIOS, set Config -> Power -> Sleep State to "Linux".
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/laptop/lenovo_thinkpad_t14_gen2.nix ];
#   custom.sysNixLenovoThinkpadT14IntelGen2.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.sysNixLenovoThinkpadT14IntelGen2.enable = lib.mkEnableOption "Lenovo ThinkPad T14 Gen 2 (Intel) chassis quirks (backlight + touchpad + TrackPoint)";
  };

  config = lib.mkIf config.custom.sysNixLenovoThinkpadT14IntelGen2.enable {
    boot.kernelParams = [
      "acpi_backlight=native" # use kernel-native backlight; required for systemd-backlight save/restore on ThinkPads
      "psmouse.synaptics_intertouch=0" # fix touchpad click registration on some T14 units
    ];

    hardware.trackpoint = {
      enable = lib.mkDefault true;
      emulateWheel = lib.mkDefault true; # middle-button-drag scrolling (classic ThinkPad behaviour)
    };
  };
}
