# FENNEC

> **Status:** Configured — registered in `flake/hosts.nix`. Pending `hardware-configuration.nix` generation on actual hardware.

NixOS desktop — ASUS PRIME X570-PRO / NVIDIA RTX 3080

## Hardware

| Component   | Model                                                                                  |
| ----------- | -------------------------------------------------------------------------------------- |
| Motherboard | ASUS PRIME X570-PRO                                                                    |
| CPU         | AMD Ryzen 9 5900X                                                                      |
| RAM         | G.Skill 32 GB (2×16 GB) DDR4 4400 MHz (F4-4400C19-16GVK)                               |
| GPU         | NVIDIA PNY GeForce RTX 3080 10 GB XLR8 Gaming REVEL EPIC-X RGB Triple Fan (LHR, GA102) |
| Storage 1   | Corsair MP600 PRO XT 4 TB NVMe — M.2_1 (CPU)                                           |
| Storage 2   | Samsung 980 PRO 2 TB NVMe — M.2_2 (chipset)                                            |
| Storage 3   | Samsung 860 EVO 500 GB — SATA                                                          |
| Storage 4   | Samsung 860 EVO 500 GB — SATA                                                          |

## Displays

| GPU output | Connection        | Sink                      | Notes                    |
| ---------- | ----------------- | ------------------------- | ------------------------ |
| DP-1       | KVM PC2 bottom DP | M1 (Gigabyte M27U)        | 4K, scale 1.7 in Plasma  |
| DP-2       | KVM PC2 top DP    | M2 (Dell P2425, portrait) | rotated right, scale 1.0 |
| HDMI-A-1   | Long HDMI direct  | TV (Samsung 55Q70R)       | EDID max mode 4096×2160  |

BIOS POSTs on **M2** ⚠️ by default — see [DISPLAYS.md](../../DISPLAYS.md#open-issue--fennec-bios-posts-on-m2). Workaround: power M2 off before cold boot, turn it back on after GRUB / SDDM appears on M1.

For the shared KVM / monitor / TV topology, see [DISPLAYS.md](../../DISPLAYS.md).

## M.2 connectors

| Slot  | Location                       | Lanes       | Connected to | Use                  |
| ----- | ------------------------------ | ----------- | ------------ | -------------------- |
| M.2_1 | Between CPU and first PCIe ×16 | PCIe 4.0 ×4 | CPU direct   | Linux game storage   |
| M.2_2 | Below PCIe slots (chipset)     | PCIe 4.0 ×4 | X570 chipset | Windows game storage |

Both slots are Socket 3, M Key, supporting Type 2242/2260/2280/22110 drives in
PCIe or SATA mode. M.2_1 includes an integrated heatsink.

The top M.2 slot (M.2_1) connects directly to the CPU and provides full PCIe 4.0
bandwidth with the Ryzen 9 3900X (Ryzen 2000 / APU processors would drop this
slot to PCIe 3.0). The bottom M.2 slot (M.2_2) runs through the X570 chipset,
sharing its uplink bandwidth with SATA ports, USB controllers, and other
chipset-connected devices.

## Disk layout

### Drive 1 — Linux OS (SATA port 1)

Samsung 860 EVO 500 GB on **SATA port 1** (`/dev/sda`). Lowest port number
ensures this drive appears first in BIOS boot order — GRUB lives here.

| Partition | Mount   | Filesystem | Size                |
| --------- | ------- | ---------- | ------------------- |
| EFI       | `/boot` | vfat       | 2 GB                |
| Root      | `/`     | ext4       | Remainder of disk   |
| Swap      | —       | swap       | ≥ 48 GB (RAM × 1.5) |

### Drive 2 — Windows OS (SATA port 2)

Samsung 860 EVO 500 GB on **SATA port 2** (`/dev/sdb`). Partitioned by the
Windows installer (EFI System Partition + C: drive). GRUB’s os-prober detects
the Windows Boot Manager on this drive automatically.

### Drive 3 — Linux game storage (M.2_1, CPU direct)

Corsair MP600 PRO XT 4 TB. Single partition mounted at the game library path
(e.g. `/home/<user>/Games`). CPU-direct lanes ensure zero-contention I/O for
asset streaming.

### Drive 4 — Windows game storage (M.2_2, chipset)

Samsung 980 PRO 2 TB. Single NTFS partition for the Windows game library.
The chipset uplink (~7.9 GB/s shared) is more than adequate for game storage.

### SATA ports

Since both M.2 slots use NVMe mode, all 6 SATA ports remain available. Ports 5
and 6 would be disabled if an M.2 slot were ever switched to SATA mode.

The SATA connectors are on the **right edge** of the PRIME X570-PRO, stacked
vertically and labeled `SATA6G_1` through `SATA6G_6` on the PCB.

| SATA Port | Drive           | OS      | Device     |
| --------- | --------------- | ------- | ---------- |
| Port 1    | Samsung 860 EVO | Linux   | `/dev/sda` |
| Port 2    | Samsung 860 EVO | Windows | `/dev/sdb` |

### Swap

The swap partition is used as the hibernation (suspend-to-disk) target and as
an overflow safety net for zram. It must be at least as large as physical RAM
(32 GB) for hibernation to work; 1.5× RAM (48 GB) is recommended to allow
headroom. Day-to-day swap is handled by zram (compressed swap in RAM) — the
disk swap partition is rarely touched during normal use.

## Bootloader

Use GRUB (EFI) with os-prober for dual-boot. The `custom.sysNixGrub.enable` module
already sets `useOSProber = true`, which automatically detects Windows on the
second SATA drive and adds a GRUB menu entry — no manual chainloading needed.

GRUB is preferred over systemd-boot here because os-prober handles Windows
detection automatically. systemd-boot would require manual EFI entry
configuration for the Windows boot partition.

**Install order** — either approach works:

1. Install Windows first on the second 860 EVO, then NixOS on the first.
   GRUB's os-prober will find Windows automatically during `nixos-install`.
2. Install NixOS first, then Windows on the second drive. Run
   `sudo nixos-rebuild switch` afterward to re-detect and add the Windows entry.

Set `custom.sysNixGrub.timeout` high enough to comfortably select the OS at
boot. The host currently uses `2` for a fast boot; bump to `3`–`5` if you find
the window too tight for selecting Windows.

## Next steps

1. Boot NixOS installer on the machine
2. Generate hardware config: `nixos-generate-config --show-hardware-config > hosts/FENNEC/configuration/hardware-configuration.nix`
3. Run `sudo nixos-rebuild switch --flake .#FENNEC`

## Hardware diagnostics

```bash
# Motherboard
nix-shell -p dmidecode --run "sudo dmidecode -t baseboard"

# Memory
nix-shell -p dmidecode --run "sudo dmidecode -t memory"

# Storage
lsblk -o NAME,MODEL
nix-shell -p smartmontools --run "sudo smartctl -a /dev/nvme0n1"   # MP600 PRO XT (M.2_1)
nix-shell -p smartmontools --run "sudo smartctl -a /dev/nvme1n1"   # 980 PRO (M.2_2)
nix-shell -p smartmontools --run "sudo smartctl -a /dev/sda"       # 860 EVO (SATA)
nix-shell -p smartmontools --run "sudo smartctl -a /dev/sdb"       # 860 EVO (SATA)
```
