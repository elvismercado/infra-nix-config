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

    # Hardware
    ../../../modules/systems/nixos/cpu/intel/tiger_lake_i5_1135g7.nix
    ../../../modules/systems/nixos/graphics/intel_iris_xe.nix
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

    # Display
    ../../../modules/systems/nixos/display_manager/sddm.nix
    ../../../modules/systems/nixos/display_manager/sddm-input-config.nix
    ../../../modules/systems/nixos/desktop_environment/kde_plasma.nix

    # Peripherals
    ../../../modules/systems/nixos/bluetooth.nix
    ../../../modules/systems/nixos/pipewire.nix

    # Power
    ../../../modules/systems/nixos/power/power-profiles-daemon.nix

    # Services
    ../../../modules/systems/nixos/fwupd.nix
    ../../../modules/systems/nixos/postinstall.nix

    # Apps (cross-layer façades — see modules/apps/)
    ../../../modules/apps/linux/brave.nix
    ../../../modules/apps/linux/localsend.nix
    ../../../modules/apps/linux/mpv.nix
  ];

  # Nix
  custom.sysNixEnableFlakes.enable = true;
  custom.sysGc.enable = true;

  # Bootloader — single-OS laptop, friendly default timeout, 1080p panel
  custom.sysNixGrub.enable = true;
  custom.sysNixGrub.timeout = 5;
  custom.sysNixGrub.gfxmodeEfi = "1920x1080,auto";
  custom.sysNixGrub.fontSize = 24;
  custom.sysNixGrubThemeSleek.enable = true;
  custom.sysNixGrubThemeSleek.style = "dark";

  # Hardware
  custom.sysNixIntelTigerLakeI51135g7.enable = true;
  custom.sysNixIntelIrisXe.enable = true;
  custom.sysNixSsd.enable = true;

  # Memory — hibernation supported (swap partition >= RAM, set via install.sh --swap-size)
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

  # Display — single built-in 14" panel; KDE handles ad-hoc external displays
  # via its own GUI. No multi-monitor / display-profiles modules wired.
  custom.sysNixSddm.enable = true;
  custom.sysNixSddmInputConfig.enable = true;
  custom.sysNixKdePlasma.enable = true;

  # Peripherals
  custom.sysNixBluetooth.enable = true;
  custom.sysNixPipewire.enable = true;

  # Power — KDE-native Performance/Balanced/Power-saver via Battery widget
  custom.sysNixPowerProfilesDaemon.enable = true;

  # Services
  custom.sysNixFwupd.enable = true;
  custom.sysNixPostinstall.enable = true;

  # Apps (cross-layer façades) — minimal persona for a non-technical user.
  # Brave with no force-installed extensions (vanilla) per LULA's profile.
  custom.appBrave.enable = true;
  custom.appBrave.extensions = [ ];
  custom.appLocalsend.enable = true;
  custom.appMpv.enable = true;
}
