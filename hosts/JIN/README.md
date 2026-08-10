# JIN

NixOS desktop — AMD Ryzen 9 / Radeon R7 430

## Hardware

| Component   | Model                                                                 |
| ----------- | --------------------------------------------------------------------- |
| Motherboard | Gigabyte X570 I AORUS PRO WIFI                                        |
| CPU         | AMD Ryzen 9 3900X                                                     |
| RAM         | Corsair Vengeance LPX 32GB (2x16GB) DDR4 3200MHz (CMK32GX4M2B3200C16) |
| GPU         | AMD Radeon R7 430 (Oland)                                             |
| Storage 1   | Crucial P2 1TB NVMe M.2 SSD (CT1000P2SSD8) — front M.2 (CPU)          |
| Storage 2   | Crucial P2 1TB NVMe M.2 SSD (CT1000P2SSD8) — back M.2 (chipset)       |

## Displays

| GPU output | Connection        | Sink                      |
| ---------- | ----------------- | ------------------------- |
| DP-1       | KVM PC1 bottom DP | M1 (Gigabyte M27U)        |
| DP-2       | KVM PC1 top DP    | M2 (Dell P2425, portrait) |

BIOS POSTs on **M1** ✅. For the shared KVM / monitor / TV topology, see [DISPLAYS.md](../../DISPLAYS.md).

The Radeon R7 430 is **DisplayPort 1.2 (HBR2)**, so M1 is capped at **4K@60Hz**
on this host. The M27U's native 160Hz needs DP 1.4 (HBR3) and is only available
on FENNEC. At 1080p the GPU can drive M1 up to 120Hz cleanly.

## M.2 connectors

| Slot | Location      | Lanes       | Connected to | Use         |
| ---- | ------------- | ----------- | ------------ | ----------- |
| M2A  | Front (top)   | PCIe 4.0 ×4 | CPU direct   | OS drive    |
| M2B  | Back (bottom) | PCIe 3.0 ×4 | X570 chipset | /home drive |

The front M.2 slot connects directly to the CPU and provides full PCIe 4.0
bandwidth (though the Crucial P2 is a PCIe 3.0 ×4 drive). The back M.2 slot
runs through the X570 chipset at PCIe 3.0 ×4 — more than adequate for a
data/home drive.

## Disk layout

### Drive 1 — OS (front M.2, CPU)

| Partition | Mount   | Filesystem | Size                |
| --------- | ------- | ---------- | ------------------- |
| EFI       | `/boot` | vfat       | 2 GB                |
| Root      | `/`     | ext4       | Remainder of disk   |
| Swap      | —       | swap       | ≥ 48 GB (RAM × 1.5) |

### Drive 2 — Home (back M.2, chipset)

| Partition | Mount   | Filesystem | Size        |
| --------- | ------- | ---------- | ----------- |
| Home      | `/home` | ext4       | Entire disk |

The entire second drive is formatted as a single ext4 partition mounted at
`/home`. This keeps user data completely separate from the OS — you can
reinstall NixOS on Drive 1 without touching `/home`.

### Swap

The swap partition is used as the hibernation (suspend-to-disk) target and as
an overflow safety net for zram. It must be at least as large as physical RAM
(32 GB) for hibernation to work; 1.5× RAM (48 GB) is recommended to allow
headroom. Day-to-day swap is handled by zram (compressed swap in RAM) — the
disk swap partition is rarely touched during normal use.

## Configuration overview

- **OS:** NixOS 25.11, x86_64-linux, stable channel
- **Desktop:** KDE Plasma + SDDM (with multi-monitor layout)
- **Bootloader:** GRUB (EFI)
- **Networking:** NetworkManager, Bluetooth (A2DP), TCP BBR, irqbalance
- **Audio:** PipeWire
- **Kernel:** Linux Zen (desktop-optimised, 1000 Hz)
- **CPU:** AMD Ryzen (P-State EPP, Zenpower, microcode updates)
- **GPU:** AMD Radeon R7 430 (Oland), AMD graphics stack
- **Storage:** 2× NVMe SSD (fstrim, noatime, tmpfs /tmp, I/O tuning)
- **Memory:** zram (compressed swap), earlyoom, hibernation
- **Input:** Wacom tablet, Logitech mouse
- **Security:** YubiKey, fingerprint reader (fprintd)
- **Printing:** CUPS
- **Virtualisation:** Docker, libvirtd / virt-manager
- **VPN:** Mullvad
- **Fan Control:** CoolerControl
- **Firmware:** fwupd
- **Shell:** Bash (with completions)
- **Garbage Collection:** Managed (Determinate Nix)

## KDE Wallet

KWallet is enabled so applications such as Nextcloud can persist credentials.
Complete this one-time setup after deploying the configuration:

1. Log out, then log in with the Linux account password rather than the
   fingerprint reader.
2. Open KDE Wallet Manager and create the wallet `kdewallet`, or change that
   wallet's password if it already exists.
3. Select classic password encryption and set the wallet password to the same
   value as the Linux account password. Never store that password in this
   repository.
4. Authenticate Nextcloud once if prompted so it can populate the wallet.

NixOS Plasma enables `kwallet-pam`, so later password logins automatically
unlock a matching `kdewallet`. Fingerprint login supplies no password and
therefore still requires a separate wallet-password prompt. When the Linux
account password changes, update the wallet password to match it.

## Wake-on-LAN

Enabled via `custom.sysNixWakeOnLan.enable = true;`. NetworkManager sets
`ethernet.wake-on-lan = magic` on every wired connection activation, so the
NIC stays armed across reconnects, suspend/resume, and shutdown.

BIOS prerequisites (Gigabyte X570 I AORUS PRO WIFI, one-time):

- **Settings → Platform Power → ErP** = `Disabled`
- **Settings → Platform Power → Resume by PCI-E Device** = `Enabled`

Discover the MAC once on the host:

```bash
ip link show | awk '/link\/ether/{print $2; exit}'
```

Wake from any peer on the same L2 segment:

```bash
nix run nixpkgs#wakeonlan -- <MAC>
```

Verify after a switch:

```bash
nmcli -f connection.id,ethernet.wake-on-lan connection show
nix shell nixpkgs#ethtool -c sudo ethtool <iface> | grep -i wake-on  # expect: Wake-on: g
```

## Installation

For a full step-by-step guide to install NixOS from scratch on this machine
(including an automated install script), see [INSTALL.md](../../scripts/nixos/INSTALL.md).

## Useful commands

```bash
# Rebuild and switch
sudo nixos-rebuild switch --flake .#JIN

# Regenerate hardware config
nixos-generate-config --show-hardware-config > ./configuration/hardware-configuration.nix
```

## Hardware diagnostics

```bash
# Motherboard
nix-shell -p dmidecode --run "sudo dmidecode -t baseboard"

# Memory
nix-shell -p dmidecode --run "sudo dmidecode -t memory"

# Storage
lsblk -o NAME,MODEL
nix-shell -p smartmontools --run "sudo smartctl -a /dev/nvme0n1"   # OS drive
nix-shell -p smartmontools --run "sudo smartctl -a /dev/nvme1n1"   # Home drive
```
