# power-profiles-daemon (PPD) — modern power profile manager
# https://gitlab.freedesktop.org/upower/power-profiles-daemon
#
# System service that exposes Performance / Balanced / Power-saver profiles
# via D-Bus. KDE Plasma 6's Power & Battery panel and the Battery widget
# in the system tray switch profiles natively against PPD — no extra UI
# config required.
#
# Mutually exclusive with TLP. PPD is the right choice for:
#   - Laptops where the user wants a one-click profile switcher
#   - KDE / GNOME systems (both integrate natively)
#   - Setups that don't need fine-grained per-device runtime PM tuning
#
# Use TLP instead if you need:
#   - Battery charge thresholds (ThinkPad-style "stop charging at 80%")
#   - Per-device USB autosuspend / PCIe ASPM rules
#   - More aggressive battery-life tuning at the cost of GUI integration
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/power/power-profiles-daemon.nix ];
#   custom.sysNixPowerProfilesDaemon.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.sysNixPowerProfilesDaemon.enable = lib.mkEnableOption "power-profiles-daemon (KDE-native Performance/Balanced/Power-saver switcher)";
  };

  config = lib.mkIf config.custom.sysNixPowerProfilesDaemon.enable {
    assertions = [
      {
        assertion = !(config.services.tlp.enable or false);
        message = "custom.sysNixPowerProfilesDaemon and services.tlp are mutually exclusive — disable one.";
      }
    ];

    services.power-profiles-daemon.enable = true;
  };
}

# Verification:
#   powerprofilesctl get        # current profile
#   powerprofilesctl list       # available profiles
#   systemctl status power-profiles-daemon
