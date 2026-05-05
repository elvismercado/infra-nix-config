{ ... }:

{
  imports = [
    # Host
    ./hardware-configuration.nix
    ./configuration.nix

    # Nix
    ../../../modules/systems/nixos/nix/enable-flakes.nix
    ../../../modules/systems/nixos/nix/garbage.nix

    # Bootloader
    ../../../modules/systems/nixos/bootloader/grub.nix
    ../../../modules/systems/nixos/bootloader/grub-theme-sleek.nix
    # Bootloader
    # parked — see TODO.md Backlog (improve before re-enabling)
    # ../../../modules/systems/nixos/bootloader/plymouth.nix
    # ../../../modules/systems/nixos/bootloader/plymouth-theme-adi1090x.nix

    # Hardware
    ../../../modules/systems/nixos/cpu/amd/ryzen_9_3900x.nix
    # ../../../modules/systems/nixos/graphics/utilities/nomodeset.nix
    ../../../modules/systems/nixos/graphics/amd_radeon_r7_430.nix
    # ../../../modules/systems/nixos/graphics/nvidia_gtx_1060.nix    # Gigabyte AORUS GTX 1060 6G 9Gbps — uncomment & swap to use
    # ../../../modules/systems/nixos/graphics/nvidia_rtx_3070_lhr.nix # Lenovo MSI RTX 3070 8G LHR — uncomment & swap to use
    ../../../modules/systems/nixos/ssd

    # Memory
    ../../../modules/systems/nixos/memory/zram.nix
    ../../../modules/systems/nixos/memory/earlyoom.nix
    ../../../modules/systems/nixos/memory/hibernation.nix

    # System
    ../../../modules/systems/nixos/packages.nix
    ../../../modules/systems/shared/bash.nix
    ../../../modules/systems/nixos/system/user.nix
    ../../../modules/systems/nixos/system/console.nix
    ../../../modules/systems/nixos/system/time.nix
    ../../../modules/systems/nixos/system/i18n.nix
    ../../../modules/systems/nixos/system/fonts.nix
    ../../../modules/systems/nixos/system/network-tuning.nix

    # Display
    ../../../modules/systems/nixos/display_manager/sddm.nix
    ../../../modules/systems/nixos/display_manager/sddm-monitor-layout.nix
    ../../../modules/systems/nixos/display_manager/sddm-input-config.nix
    ../../../modules/systems/nixos/desktop_environment/kde_plasma.nix

    # Input
    ../../../modules/systems/nixos/mouse/logitech.nix
    ../../../modules/systems/nixos/input/wacom.nix

    # Peripherals
    ../../../modules/systems/nixos/bluetooth.nix
    ../../../modules/systems/nixos/pipewire.nix

    # Security
    ../../../modules/systems/nixos/security/yubikey.nix
    ../../../modules/systems/nixos/security/fprintd.nix

    # Services
    ../../../modules/systems/nixos/printing.nix
    ../../../modules/systems/nixos/fwupd.nix
    ../../../modules/systems/nixos/docker.nix
    ../../../modules/systems/nixos/mullvad.nix
    ../../../modules/systems/nixos/postinstall.nix

    # Apps
    ../../../modules/systems/nixos/apps/adb.nix
    ../../../modules/systems/nixos/apps/embedded.nix
    ../../../modules/systems/nixos/apps/libvirtd.nix
    ../../../modules/systems/nixos/apps/coolercontrol.nix
  ];

  # Host
  # (no host-level toggles)

  # Nix
  custom.sysNixEnableFlakes.enable = true;
  custom.sysGc.enable = true;

  # Bootloader
  custom.sysNixGrub.enable = true;
  custom.sysNixGrub.timeout = 2;
  custom.sysNixGrub.gfxmodeEfi = "3840x2160,2560x1440,1920x1200,1920x1080,auto"; # 4K → 1440p → 1200p → 1080p → auto fallback
  custom.sysNixGrubThemeSleek.enable = true;
  custom.sysNixGrubThemeSleek.style = "dark";
  # Plymouth — parked, see TODO.md Backlog (improve before re-enabling)
  # custom.sysNixPlymouth.enable = true;
  # custom.sysNixPlymouth.bootDisabledOutputs = [ "DP-2" ]; # auto-adds video=DP-2:d, re-enables before display manager
  # custom.sysNixPlymouth.useSimpleDrm = false; # disable SimpleDRM — amdgpu forced-SI ignores video=DP-2:d either way
  # custom.sysNixPlymouth.minAnimationDuration = 3; # NVMe boots fast — ensure animation plays
  # custom.sysNixPlymouth.minShutdownDuration = 3; # NVMe shuts down fast — ensure splash is visible
  # custom.sysNixPlymouth.debug = true; # writes /var/log/plymouth-debug.log
  # custom.sysNixPlymouthThemeAdi1090x.enable = true;
  # custom.sysNixPlymouthThemeAdi1090x.theme = "circuit";

  # Hardware
  custom.sysNixAmdRyzen93900x.enable = true; # Ryzen 9 3900X profile (ryzen + pstate + zenpower)
  # custom.sysNixNomodeset.enable = true;
  # custom.sysNixNomodeset.efifbMode = "2560x1440-32@100";
  custom.sysNixAmdRadeonR7430.enable = true;
  # custom.sysNixNvidiaGtx1060.enable = true;   # ← uncomment (and comment amdRadeonR7430 above) to swap GPU
  # custom.sysNixNvidiaRtx3070Lhr.enable = true; # ← uncomment (and comment amdRadeonR7430 above) to swap GPU
  custom.sysNixSsd.enable = true;

  # Memory
  custom.sysNixZram.enable = true;
  custom.sysNixEarlyoom.enable = true;
  custom.sysNixHibernate.enable = true;

  # System
  custom.sysPackages.enable = true;
  custom.sysBashCompletion.enable = true;
  custom.sysNixUser.enable = true;
  custom.sysNixConsole.enable = true;
  custom.sysNixTimezone.enable = true;
  custom.sysNixI18n.enable = true;
  custom.sysFonts.enable = true;
  custom.sysNixNetworkTuning.enable = true;

  # Display
  custom.sysNixSddm.enable = true;
  custom.sysNixSddmMonitorLayout.enable = true;
  custom.sysNixSddmInputConfig.enable = true;
  custom.sysNixKdePlasma.enable = true;

  # Input
  custom.sysNixLogitechMouse.enable = true;
  custom.sysNixWacom.enable = true;

  # Peripherals
  custom.sysNixBluetooth.enable = true;
  custom.sysNixPipewire.enable = true;

  # Security
  custom.sysNixYubikey.enable = true;
  custom.sysNixFprintd.enable = true;

  # Services
  custom.sysNixPrinting.enable = true;
  custom.sysNixFwupd.enable = true;
  custom.sysNixDocker.enable = true;
  custom.sysNixMullvad.enable = true;
  custom.sysNixPostinstall.enable = true;

  # Apps
  custom.sysNixAdb.enable = true;
  custom.sysNixCoolercontrol.enable = true;
  custom.sysNixEmbedded.enable = true;
  custom.sysNixLibvirtd.enable = true;
}
