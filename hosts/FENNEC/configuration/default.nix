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
    ../../../modules/systems/nixos/bootloader/plymouth.nix
    ../../../modules/systems/nixos/bootloader/plymouth-theme-adi1090x.nix

    # Hardware
    ../../../modules/systems/nixos/cpu/amd/ryzen_9_5900x.nix
    ../../../modules/systems/nixos/graphics/nvidia_rtx_3080.nix
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
    ../../../modules/systems/nixos/desktop_environment/kde_plasma.nix

    # Peripherals
    ../../../modules/systems/nixos/bluetooth.nix
    ../../../modules/systems/nixos/pipewire.nix
    ../../../modules/systems/nixos/mouse/logitech.nix

    # Services
    ../../../modules/systems/nixos/fwupd.nix
    ../../../modules/systems/nixos/mullvad.nix
    ../../../modules/systems/nixos/postinstall.nix

    # Apps
    ../../../modules/systems/nixos/apps/coolercontrol.nix
    ../../../modules/systems/nixos/apps/sunshine.nix

    # Gaming
    ../../../modules/systems/nixos/gaming/steam.nix
  ];

  # Nix
  custom.sysNixEnableFlakes.enable = true;
  custom.sysGc.enable = true;

  # Bootloader
  custom.sysNixGrub.enable = true;
  custom.sysNixGrub.timeout = 5; # dual-boot — give time to select OS
  custom.sysNixGrubThemeSleek.enable = true;
  custom.sysNixGrubThemeSleek.style = "dark";
  custom.sysNixPlymouth.enable = true;
  custom.sysNixPlymouth.minAnimationDuration = 3; # NVMe boots fast — ensure animation plays
  custom.sysNixPlymouth.minShutdownDuration = 3;
  custom.sysNixPlymouthThemeAdi1090x.enable = true;
  custom.sysNixPlymouthThemeAdi1090x.theme = "circuit";

  # Hardware
  custom.sysNixAmdRyzen95900x.enable = true;
  custom.sysNixNvidiaRtx3080.enable = true;
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
  custom.sysNixNetworkTuning.congestionControl = "cubic"; # gaming host — BBR collapses Steam/Akamai downloads to ~150 Mbps

  # Display
  custom.sysNixSddm.enable = true;
  custom.sysNixKdePlasma.enable = true;

  # Peripherals
  custom.sysNixBluetooth.enable = true;
  custom.sysNixPipewire.enable = true;
  custom.sysNixLogitechMouse.enable = true;

  # Services
  custom.sysNixFwupd.enable = true;
  custom.sysNixMullvad.enable = true;
  custom.sysNixPostinstall.enable = true;

  # Apps
  custom.sysNixCoolercontrol.enable = true;
  custom.sysNixSunshine.enable = true;

  # Gaming
  custom.sysNixSteam.enable = true;
}
