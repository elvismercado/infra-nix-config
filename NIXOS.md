# NixOS

NixOS system configuration is managed through `flake/nixos.nix`. Each NixOS host gets a full system build using `selectedNixpkgs.lib.nixosSystem`, where the nixpkgs version is determined by the host's `channel` setting.

## Current Hosts

| Host   | Architecture | Channel | User   | Notes                                             |
| ------ | ------------ | ------- | ------ | ------------------------------------------------- |
| JIN    | x86_64-linux | stable  | jin    | Desktop — Ryzen 9 3900X / Radeon R7 430           |
| FENNEC | x86_64-linux | stable  | fennec | Desktop — Ryzen 9 5900X / RTX 3080                |
| LULA   | x86_64-linux | stable  | lula   | Laptop — ThinkPad T14 Gen 2 / i5-1135G7 / Iris Xe |

## Rebuild

Rebuild the system configuration from the flake:

```bash
# Rebuild using the host's flake configuration
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC
sudo nixos-rebuild switch --flake .#LULA

# Rebuild from the current directory (uses hostname to find config)
sudo nixos-rebuild switch --flake .
```

## How It Works

1. Hosts are registered in `flake/hosts.nix` under `nixosHosts`
2. `flake/nixos.nix` iterates over all NixOS hosts and builds a `nixosSystem` for each
3. The nixpkgs channel (stable/unstable) is selected per-host based on `channel` in `user-settings.nix` via `selectNixpkgs`
4. The Home Manager version (stable/unstable) is also selected per-host via `selectHomeManager` — a `"stable"` host uses `home-manager-stable`, an `"unstable"` host uses `home-manager`
5. The [Determinate Nix](https://determinate.systems/) module is included in all NixOS builds
6. Home Manager is integrated as a NixOS module (not standalone) for system rebuilds

### What gets passed to modules

Every NixOS module receives these via `specialArgs`:

- `inputs` — all flake inputs (access `inputs.nixpkgs-stable`, `inputs.home-manager`, etc.)
- `userSettings` — the host's `user-settings.nix` (`username`, `hostname`, `system`, `channel`; optional `timeZone`)
- `outputs` — the flake's own outputs

## Toggleable Modules

All modules under `modules/systems/nixos/` use the `custom.*` namespace and must be explicitly enabled. Import the module in your host's `configuration/default.nix` and set the enable flag:

```nix
{
  imports = [
    ../../../modules/systems/nixos/printing.nix
  ];

  custom.sysNixPrinting.enable = true;
}
```

Modules default to `false` — importing without enabling has no effect.

### Available NixOS Modules

| Module                                                   | Option                                                                  |
| -------------------------------------------------------- | ----------------------------------------------------------------------- |
| `systems/nixos/packages.nix`                             | `custom.sysPackages.enable`                                             |
| **Nix**                                                  |                                                                         |
| `systems/nixos/nix/enable-flakes.nix`                    | `custom.sysNixEnableFlakes.enable`                                      |
| `systems/nixos/nix/garbage.nix`                          | `custom.sysGc.enable`                                                   |
| `systems/nixos/printing.nix`                             | `custom.sysNixPrinting.enable`                                          |
| `systems/nixos/fwupd.nix`                                | `custom.sysNixFwupd.enable`                                             |
| `systems/nixos/docker.nix`                               | `custom.sysNixDocker.enable`                                            |
| `systems/nixos/postinstall.nix`                          | `custom.sysNixPostinstall.enable`                                       |
| **Peripherals**                                          |                                                                         |
| `systems/nixos/bluetooth.nix`                            | `custom.sysNixBluetooth.enable`                                         |
| `systems/nixos/pipewire.nix`                             | `custom.sysNixPipewire.enable`                                          |
| **Memory**                                               |                                                                         |
| `systems/nixos/memory/zram.nix`                          | `custom.sysNixZram.enable`                                              |
| `systems/nixos/memory/earlyoom.nix`                      | `custom.sysNixEarlyoom.enable`                                          |
| `systems/nixos/memory/hibernation.nix`                   | `custom.sysNixHibernate.enable`                                         |
| **Bootloader**                                           |                                                                         |
| `systems/nixos/bootloader/grub.nix`                      | `custom.sysNixGrub.enable`                                              |
| `systems/nixos/bootloader/grub-theme-sleek.nix`          | `custom.sysNixGrubThemeSleek.enable`                                    |
|                                                          | `custom.sysNixGrubThemeSleek.style`                                     |
| `systems/nixos/bootloader/grub-theme-breeze.nix`         | `custom.sysNixGrubThemeBreeze.enable`                                   |
| `systems/nixos/bootloader/grub-theme-nixos.nix`          | `custom.sysNixGrubThemeNixos.enable`                                    |
| `systems/nixos/bootloader/systemd-boot.nix`              | `custom.sysNixSystemdBoot.enable`                                       |
| `systems/nixos/bootloader/plymouth.nix`                  | `custom.sysNixPlymouth.enable`                                          |
| `systems/nixos/bootloader/plymouth-theme-builtin.nix`    | `custom.sysNixPlymouthThemeBuiltin.enable`                              |
|                                                          | `custom.sysNixPlymouthThemeBuiltin.theme`                               |
| `systems/nixos/bootloader/plymouth-theme-nixos.nix`      | `custom.sysNixPlymouthThemeNixos.enable`                                |
| `systems/nixos/bootloader/plymouth-theme-breeze.nix`     | `custom.sysNixPlymouthThemeBreeze.enable`                               |
| `systems/nixos/bootloader/plymouth-theme-adi1090x.nix`   | `custom.sysNixPlymouthThemeAdi1090x.enable`                             |
|                                                          | `custom.sysNixPlymouthThemeAdi1090x.theme`                              |
| **CPU**                                                  |                                                                         |
| `systems/nixos/cpu/amd/base.nix`                         | `custom.sysNixAmdCpu.enable`                                            |
| `systems/nixos/cpu/amd/ryzen.nix`                        | `custom.sysNixAmdRyzenCpu.enable`                                       |
| `systems/nixos/cpu/amd/pstate.nix`                       | `custom.sysNixAmdPstate.enable`                                         |
| `systems/nixos/cpu/amd/zenpower.nix`                     | `custom.sysNixAmdZenpower.enable`                                       |
| `systems/nixos/cpu/amd/zen-kernel.nix`                   | `custom.sysNixZenKernel.enable`                                         |
| `systems/nixos/cpu/amd/mitigations-off.nix`              | `custom.sysNixCpuMitigationsOff.enable`                                 |
| `systems/nixos/cpu/intel/base.nix`                       | `custom.sysNixIntelCpu.enable`                                          |
| **CPU Profiles** (import one per host)                   |                                                                         |
| `systems/nixos/cpu/amd/ryzen_9_3900x.nix`                | `custom.sysNixAmdRyzen93900x.enable`                                    |
| `systems/nixos/cpu/amd/ryzen_9_5900x.nix`                | `custom.sysNixAmdRyzen95900x.enable`                                    |
| `systems/nixos/cpu/intel/tiger_lake_i5_1135g7.nix`       | `custom.sysNixIntelTigerLakeI51135g7.enable`                            |
| **Desktop Environment**                                  |                                                                         |
| `systems/nixos/desktop_environment/cosmic.nix`           | `custom.sysNixCosmicDesktop.enable`                                     |
| `systems/nixos/desktop_environment/kde_plasma.nix`       | `custom.sysNixKdePlasma.enable`                                         |
| **Display Manager**                                      |                                                                         |
| `systems/nixos/display_manager/sddm.nix`                 | `custom.sysNixSddm.enable`                                              |
| `systems/nixos/display_manager/sddm-monitor-layout.nix`  | `custom.sysNixSddmMonitorLayout.enable`                                 |
| `systems/nixos/display_manager/sddm-input-config.nix`    | `custom.sysNixSddmInputConfig.enable`                                   |
| **Graphics**                                             |                                                                         |
| `systems/nixos/graphics/amd_radeon_r7_430.nix`           | `custom.sysNixAmdRadeonR7430.enable`                                    |
| `systems/nixos/graphics/intel_arc_a380-intel-driver.nix` | `custom.sysNixIntelArcIntelDriver.enable`                               |
| `systems/nixos/graphics/intel_iris_xe.nix`               | `custom.sysNixIntelIrisXe.enable`                                       |
| `systems/nixos/graphics/nvidia_gtx_1060.nix`             | `custom.sysNixNvidiaGtx1060.enable`                                     |
| `systems/nixos/graphics/nvidia_rtx_3070_lhr.nix`         | `custom.sysNixNvidiaRtx3070Lhr.enable`                                  |
| `systems/nixos/graphics/nvidia_rtx_3080.nix`             | `custom.sysNixNvidiaRtx3080.enable`                                     |
| **Graphics — Utilities**                                 |                                                                         |
| `systems/nixos/graphics/utilities/amd.nix`               | `custom.sysNixAmdGraphics.enable`                                       |
| `systems/nixos/graphics/utilities/nomodeset.nix`         | `custom.sysNixNomodeset.enable`                                         |
| `systems/nixos/graphics/utilities/nvtop-intel.nix`       | `custom.sysNixNvtopIntel.enable`                                        |
| `systems/nixos/graphics/utilities/nvtop-nvidia.nix`      | `custom.sysNixNvtopNvidia.enable`                                       |
| **Input**                                                |                                                                         |
| `systems/nixos/input/wacom.nix`                          | `custom.sysNixWacom.enable`                                             |
| **Mouse**                                                |                                                                         |
| `systems/nixos/mouse/logitech.nix`                       | `custom.sysNixLogitechMouse.enable`                                     |
| **Power**                                                |                                                                         |
| `systems/nixos/power/power-profiles-daemon.nix`          | `custom.sysNixPowerProfilesDaemon.enable`                               |
| **Security**                                             |                                                                         |
| `systems/nixos/security/fprintd.nix`                     | `custom.sysNixFprintd.enable`                                           |
| `systems/nixos/security/yubikey.nix`                     | `custom.sysNixYubikey.enable`                                           |
| **SSD**                                                  |                                                                         |
| `systems/nixos/ssd/default.nix`                          | `custom.sysNixSsd.enable`                                               |
| **System**                                               |                                                                         |
| `systems/nixos/system/user.nix`                          | `custom.sysNixUser.enable`                                              |
|                                                          | `custom.sysNixUser.extraGroups`                                         |
| `systems/nixos/system/console.nix`                       | `custom.sysNixConsole.enable`                                           |
|                                                          | `custom.sysNixConsole.colorScheme`                                      |
| `systems/nixos/system/fonts.nix`                         | `custom.sysFonts.enable`                                                |
| `systems/nixos/system/i18n.nix`                          | `custom.sysNixI18n.enable`                                              |
| `systems/nixos/system/time.nix`                          | `custom.sysNixTimezone.enable`                                          |
| `systems/nixos/system/network-tuning.nix`                | `custom.sysNixNetworkTuning.enable`                                     |
| **Apps**                                                 |                                                                         |
| `systems/nixos/apps/adb.nix`                             | `custom.sysNixAdb.enable`                                               |
| `systems/nixos/apps/coolercontrol.nix`                   | `custom.sysNixCoolercontrol.enable`                                     |
| `systems/nixos/apps/embedded.nix`                        | `custom.sysNixEmbedded.enable`                                          |
| `systems/nixos/apps/libvirtd.nix`                        | `custom.sysNixLibvirtd.enable`                                          |
| `systems/nixos/apps/sunshine.nix`                        | `custom.sysNixSunshine.enable`                                          |
| `systems/nixos/brave-policies.nix`                       | `custom.sysBravePolicies.enable` (managed via `custom.appBrave.enable`) |
| **Shared** (cross-platform)                              |                                                                         |
| `systems/shared/bash.nix`                                | `custom.sysBashCompletion.enable`                                       |
| `systems/shared/fonts.nix`                               | `custom.sysFonts.enable`                                                |
| `systems/shared/packages.nix`                            | `custom.sysPackages.enable`                                             |
| `systems/shared/ssh-server.nix`                          | `custom.sysSshServer.enable`                                            |

> Shared modules are imported indirectly — e.g. `nixos/nix/garbage.nix` imports `shared/garbage.nix` and layers on NixOS-specific `nix.gc` settings. You import the platform wrapper, not the shared file directly.

## Adding a New NixOS Host

1. Create the host directory:

   ```
   hosts/<HOSTNAME>/
     user-settings.nix
     configuration/
       default.nix
       configuration.nix
       hardware-configuration.nix
       user.nix
     home-manager/
       default.nix
       home.nix
   ```

2. Define `user-settings.nix`:

   ```nix
   {
     username = "myuser"; # username or name of the system user
     hostname = "MYHOST"; # description / hostname (must match networking.hostName)
     system = "x86_64-linux";
     channel = "stable"; # "stable" or "unstable"
     # timeZone = "Etc/UTC"; # optional — typically set in the nix-config-private overlay; default Etc/UTC
     uid = 1000; # UID for the system user — must match install script chown
     repoPath = "git/nix-config"; # relative to $HOME
     desktopEnvironment = "kde-plasma"; # "kde-plasma", "cosmic", or null
   }
   ```

3. Generate the hardware configuration:

   ```bash
   nixos-generate-config --show-hardware-config > hosts/<HOSTNAME>/configuration/hardware-configuration.nix
   ```

4. Register the host in `flake/hosts.nix`:

   ```nix
   nixosHosts = {
     MYHOST = mkHost "MYHOST";
   };
   ```

5. Rebuild:

   ```bash
   sudo nixos-rebuild switch --flake .#MYHOST
   ```

## Garbage Collection

```bash
# Delete all old generations
nix-collect-garbage -d

# Delete generations older than 7 days
nix-collect-garbage --delete-older-than 7d
```

> With Determinate Nix, managed garbage collection runs automatically in the background via Determinate Nixd.
