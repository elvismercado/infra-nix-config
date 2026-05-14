# LULA

Linux laptop — Lenovo ThinkPad T14 Gen 2 (2021), Intel Tiger Lake.
Personal machine for a non-technical user, set up as a low-friction host.

> **Migration in progress.** LULA was previously a 2026 MacBook Neo
> (aarch64-darwin / nix-darwin). New hardware below; NixOS install and
> repo wiring land in a follow-up round. See [Status](#status).

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

- Fingerprint reader — expected to work via `fprintd` on NixOS.
- IR camera (Windows Hello face unlock) — **Linux-side loss**, no
  practical equivalent.

## Status

This host is mid-migration from macOS to NixOS:

- ✅ **Round 1 (done):** specs and cross-host docs updated to reflect the
  new hardware. `user-settings.nix` already declares
  `system = "x86_64-linux"` and `desktopEnvironment = "kde-plasma"`.
- ⏳ **Round 2 (pending):** install NixOS on the laptop, capture
  `hardware-configuration.nix`, rewrite `configuration/` and
  `home-manager/` for KDE Plasma + NetworkManager + fprintd + TLP /
  power-profiles + PipeWire + Bluetooth, swap the Brave façade from
  darwin to linux, retire `users.knownUsers` / Homebrew / cask wiring,
  flip `metadata.os` to `"nixos"`, and move LULA in `flake/hosts.nix`
  from `darwinHosts` to `nixosHosts`.

Until Round 2 ships, `metadata.os` stays `"darwin"` so the flake keeps
evaluating. **Do not run `darwin-rebuild` against the new hardware** —
the macOS-shaped configuration cannot apply on Linux.

### Expected Linux-side losses vs the old macOS host

- IR-camera face unlock (Windows Hello). Use the fingerprint reader.
- AppCleaner (cask-only). No declarative-uninstall workflow planned.
- macOS-style System Settings panes (Trackpad, Power, Security). Replaced
  by KDE System Settings + the relevant `custom.sysNix*` modules.

## Configuration overview (planned)

- **OS:** NixOS 25.11 (Xantusia), x86_64-linux, stable channel
- **Desktop:** KDE Plasma + SDDM
- **Shell:** Bash (with completions), Starship prompt (pastel-powerline)
- **Networking:** NetworkManager, Bluetooth
- **Audio:** PipeWire
- **Environment:** UI language, regional formats, and timezone come from
  the `nix-config-private` overlay. Falls back to `en-GB` / `Etc/UTC`
  when the overlay is missing.
- **Fonts:** Nerd Fonts, Google Fonts
- **Power:** TLP / power-profiles-daemon (laptop-tuned)
- **Security:** fingerprint reader (`fprintd`)
- **CLI:** Fastfetch, mpv, SSH, shell aliases — no dev tooling, no
  Syncthing.

## Installed applications (planned)

LULA intentionally runs a minimal app set:

- **Brave** — primary browser. Managed policies (debrand + privacy) are
  applied, but **no force-installed extensions**
  (`custom.appBrave.extensions = []`). The user can install whatever
  they want from the Chrome Web Store.
- **LocalSend** — cross-device file sharing.

## Useful commands

```bash
# After Round 2 — rebuild and switch
sudo nixos-rebuild switch --flake .#LULA

# Or use the shell alias from anywhere
switch
```
