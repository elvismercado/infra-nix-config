# LULA

Linux laptop — Lenovo ThinkPad T14 Gen 2 (2021), Intel Tiger Lake.
Personal machine for a non-technical user, set up as a low-friction host.

## Hardware

| Component | Model                                                       |
| --------- | ----------------------------------------------------------- |
| Machine   | Lenovo ThinkPad T14 Gen 2 (model `20W0004DMH`, June 2021)   |
| CPU       | Intel Core i5-1135G7 (Tiger Lake, 4C/8T, 2.4–4.2 GHz, 8 MB) |
| iGPU      | Intel Iris Xe Graphics                                      |
| RAM       | 16 GB DDR4-3200 (2× 8 GB SODIMM, 1 slot upgradeable)        |
| Storage   | 256 GB PCIe NVMe SSD                                        |
| Display   | 14" FHD IPS 1920×1080, 400 nits, 1200:1 contrast            |
| Battery   | 91% capacity, 245 cycles                                    |
| BIOS      | 1.69 (5 Jan 2026)                                           |
| PSU       | Lenovo USB-C 65 W                                           |
| Build     | MIL-STD-810G (spill-resistant keyboard with drainage)       |

### Connectivity

- HDMI, 2× USB-A, 2× USB-C (both Thunderbolt 4)
- 3.5 mm headset, RJ45 Ethernet
- Wi-Fi 6E, Bluetooth 5.x
- microSD card reader

### Biometrics

- Fingerprint reader — supported via `fprintd` (not wired in this round;
  see [Future work](#future-work)).
- IR camera (Windows Hello face unlock) — no Linux equivalent.

## Configuration overview

- **OS:** NixOS 25.11 (Xantusia), x86_64-linux, stable channel
- **Bootloader:** GRUB with sleek dark theme (1080p, single-OS, 2 s timeout)
- **Desktop:** KDE Plasma + SDDM (Wayland)
- **CPU/GPU:** Intel Tiger Lake i5-1135G7 (`custom.sysNixIntelTigerLakeI51135g7`)
  + Intel Iris Xe (`custom.sysNixIntelIrisXe`, VA-API via iHD)
- **Memory:** zram + earlyoom + hibernation (swap partition >= 16 GB RAM)
- **Power:** power-profiles-daemon — Performance / Balanced / Power-saver
  via the KDE Battery widget
- **Networking:** NetworkManager (auto-enabled by `custom.sysNixUser`)
- **Audio:** PipeWire
- **Bluetooth:** enabled
- **Environment:** UI language, regional formats, and timezone come from
  the `nix-config-private` overlay. Falls back to `en-GB` / `Europe/London`
  when the overlay is missing.
- **Fonts:** Nerd Fonts, Google Fonts
- **Shell:** Bash with completions, Starship prompt (`pastel-powerline`)
- **CLI:** Fastfetch, mpv, SSH, shell aliases — no dev tooling, no
  Syncthing.

## Installed applications

LULA intentionally runs a minimal app set:

- **Brave** — primary browser. Managed policies (debrand + privacy) are
  applied, but **no force-installed extensions**
  (`custom.appBrave.extensions = []`). The user can install whatever
  they want from the Chrome Web Store.
- **LocalSend** — cross-device file sharing.
- **mpv** — media player.

## Install

This host is installed using the same flow as any other NixOS host in
this flake. See [scripts/nixos/INSTALL.md](../../scripts/nixos/INSTALL.md)
for the full procedure. Recommended invocation for LULA's single 256 GB
NVMe with hibernation-capable swap:

```bash
bash /tmp/nix-config/scripts/nixos/install.sh /dev/nvme0n1 \
  --host LULA --efi-size 1G --swap-size 20G
```

After reboot, log in as `lula` (initial password: `lula`), change it with
`passwd`, and rebuild:

```bash
sudo nixos-rebuild switch --flake .#LULA
```

## Useful commands

```bash
# Rebuild and switch
sudo nixos-rebuild switch --flake .#LULA

# Or use the shell alias from anywhere
switch

# Power profile
powerprofilesctl get
powerprofilesctl set performance   # or balanced / power-saver
```

## Future work

- **Fingerprint login.** The reader is supported by `fprintd`. Wire
  `custom.sysNixFprintd.enable = true;` and run `fprintd-enroll`
  post-install when desired.
- **Declarative KDE Plasma config.** Defaults from KDE's first-run
  wizard for now; pin theme/panel/taskbar via `hmPlasmaConfig` once
  preferences settle.
