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

    # Network
    ../../../modules/systems/nixos/network/wake-on-lan.nix

    # Display
    ../../../modules/systems/nixos/display_manager/sddm.nix
    ../../../modules/systems/nixos/display_manager/sddm-monitor-layout.nix
    ../../../modules/systems/nixos/display_manager/sddm-input-config.nix
    ../../../modules/systems/nixos/desktop_environment/kde_plasma.nix

    # Peripherals
    ../../../modules/systems/nixos/bluetooth.nix
    ../../../modules/systems/nixos/pipewire.nix
    ../../../modules/systems/nixos/mouse/logitech.nix

    # Security
    ../../../modules/systems/nixos/security/yubikey.nix
    ../../../modules/systems/nixos/security/fprintd.nix

    # Services
    ../../../modules/systems/nixos/fwupd.nix
    ../../../modules/systems/nixos/postinstall.nix

    # Apps
    ../../../modules/systems/nixos/apps/coolercontrol.nix
    ../../../modules/systems/nixos/apps/sunshine.nix

    # Apps (cross-layer façades — see modules/apps/)
    ../../../modules/apps/linux/brave.nix
    ../../../modules/apps/linux/librewolf.nix
    ../../../modules/apps/linux/localsend.nix
    ../../../modules/apps/linux/vscode.nix
    ../../../modules/apps/linux/syncthing.nix
    ../../../modules/apps/linux/handbrake.nix
    ../../../modules/apps/linux/mpv.nix
    ../../../modules/apps/linux/discord.nix
    ../../../modules/apps/linux/steam.nix
    ../../../modules/apps/linux/mullvad-vpn.nix
    ../../../modules/apps/linux/beeper.nix
    ../../../modules/apps/linux/ferdium.nix
  ];

  # Nix
  custom.sysNixEnableFlakes.enable = true;
  custom.sysGc.enable = true;

  # Bootloader
  custom.sysNixGrub.enable = true;
  custom.sysNixGrub.timeout = 2; # dual-boot — short window; be ready at boot to pick Windows
  # custom.sysNixGrub.gfxmodeEfi = "3840x2160,2560x1440,1920x1200,1920x1080,auto"; # 4K → 1440p → 1200p → 1080p → auto fallback
  custom.sysNixGrub.gfxmodeEfi = "1920x1200,1920x1080,auto"; # 1200p → 1080p → auto fallback
  custom.sysNixGrub.fontSize = 32; # 4K-friendly font for menu + editor (`e` key)
  custom.sysNixGrubThemeSleek.enable = true;
  custom.sysNixGrubThemeSleek.style = "dark";

  # Plymouth — parked, see TODO.md Backlog (improve before re-enabling)
  # custom.sysNixPlymouth.enable = true;
  # custom.sysNixPlymouth.minAnimationDuration = 3; # NVMe boots fast — ensure animation plays
  # custom.sysNixPlymouth.minShutdownDuration = 3;
  # custom.sysNixPlymouthThemeAdi1090x.enable = true;
  # custom.sysNixPlymouthThemeAdi1090x.theme = "circuit";

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

  # Network
  custom.sysNixWakeOnLan.enable = true;

  # Display
  custom.sysNixSddm.enable = true;
  custom.sysNixSddmMonitorLayout.enable = true;
  custom.sysNixSddmInputConfig.enable = true;
  custom.sysNixKdePlasma.enable = true;

  # Peripherals
  custom.sysNixBluetooth.enable = true;
  custom.sysNixPipewire.enable = true;
  custom.sysNixLogitechMouse.enable = true;

  # Security
  # Yubikey accessed via dock USB; fprintd uses FENNEC's onboard fingerprint reader.
  custom.sysNixYubikey.enable = true;
  custom.sysNixFprintd.enable = true;

  # Services
  custom.sysNixFwupd.enable = true;
  custom.sysNixPostinstall.enable = true;

  # Apps
  custom.sysNixCoolercontrol.enable = true;
  custom.sysNixSunshine.enable = true;

  # Apps (cross-layer façades)
  custom.appBrave.enable = true;
  custom.appLibrewolf.enable = true;
  custom.appLocalsend.enable = true;
  custom.appVscode.enable = true;
  custom.appSyncthing.enable = true;
  custom.appHandbrake.enable = true;
  custom.appMpv.enable = true;
  custom.appDiscord.enable = true;
  custom.appSteam.enable = true;
  custom.appMullvadVpn.enable = true;
  custom.appBeeper.enable = true;
  custom.appFerdium.enable = true;
}
