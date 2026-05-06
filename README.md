# Nix Configuration

Declarative system and user configuration for NixOS and macOS using Nix flakes, nix-darwin, and Home Manager.

## System Documentation

- [INSTALL.md](scripts/nixos/INSTALL.md) — Fresh NixOS install guide (partitioning, formatting, flake-based install)
- [NIXOS.md](NIXOS.md) — NixOS system configuration, rebuild commands, adding hosts
- [DARWIN.md](DARWIN.md) — macOS (nix-darwin) configuration, rebuild commands, adding hosts
- [HOME-MANAGER.md](HOME-MANAGER.md) — User-level configuration (dotfiles, apps, shell), works across all systems
- [DISPLAYS.md](DISPLAYS.md) — Shared monitor / KVM / TV topology and per-host display wiring

## Hosts

| Host   | System             | Architecture  | Channel | Docs                               |
| ------ | ------------------ | ------------- | ------- | ---------------------------------- |
| JIN    | NixOS              | x86_64-linux  | stable  | [Hardware](hosts/JIN/README.md)    |
| FENNEC | NixOS              | x86_64-linux  | stable  | [Hardware](hosts/FENNEC/README.md) |
| EDGE   | macOS (nix-darwin) | x86_64-darwin | stable  | [Hardware](hosts/EDGE/README.md)   |

## Quick Commands

```bash
# NixOS — rebuild system
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC

# macOS — rebuild system
darwin-rebuild switch --flake .#EDGE
```

> Home Manager is integrated as a system module on all hosts, so it is applied as part of the system rebuild above. Standalone `home-manager switch` is reserved for future non-NixOS/non-darwin hosts (e.g. Ubuntu, Arch) registered in `homeManagerHosts`.

## Quickstart

Install [Determinate Nix](https://determinate.systems/) and clone this repo:

```bash
# Copy setup.sh to your home folder and run it
chmod +x setup.sh
./setup.sh
```

Or install manually:

```bash
# Install Determinate Nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate

# Clone the repo
mkdir -p ~/git
git clone https://github.com/elvismercado/nix-config ~/git/nix-config
```

> All hosts default to `channel = "stable"`. To switch a host to `unstable`,
> see [Per-Host Settings](#per-host-settings) below.

## Repository Structure

```
flake.nix                   # Flake entry point (inputs + formatter)
flake/
  default.nix               # Orchestrator — wires hosts into builders
  hosts.nix                 # Host registries + channel selectors
  nixos.nix                 # nixosConfigurations builder
  darwin.nix                # darwinConfigurations builder
  home.nix                  # homeConfigurations builder
hosts/
  <HOSTNAME>/
    user-settings.nix        # Per-host settings (username, system, channel, etc.)
    configuration/           # System configuration (NixOS or Darwin modules)
    home-manager/            # Home Manager modules for this host
modules/
  systems/
    nixos/                   # NixOS system modules (toggleable, custom.* namespace)
      apps/                  #   ADB, Coolercontrol, embedded, libvirtd, sunshine
      bootloader/            #   GRUB, systemd-boot, Plymouth, GRUB/Plymouth themes
      cpu/amd/               #   AMD base, Ryzen, P-State, Zenpower, zen-kernel, mitigations-off + CPU profiles (3900X, 5900X)
      desktop_environment/   #   KDE Plasma, COSMIC
      display_manager/       #   SDDM, SDDM monitor layout, SDDM input config
      gaming/                #   Steam, Proton, GameMode, Gamescope, Lutris
      graphics/              #   AMD, Intel Arc, NVIDIA, nomodeset, nvtop
      input/                 #   Wacom
      memory/                #   zram, earlyoom, hibernation
      mouse/                 #   Logitech
      nix/                   #   Flakes, garbage collection
      security/              #   YubiKey, fprintd
      ssd/                   #   SSD optimisations (fstrim)
      system/                #   Console, fonts, i18n, network tuning, time, user
      bluetooth.nix          #   Bluetooth + A2DP audio
      pipewire.nix           #   PipeWire audio server
    darwin/                  # Darwin-specific modules (Alacritty, Control Center, Dock, Finder,
                             #   fonts, gc, packages, Power, Security, System Preferences, Trackpad)
    shared/                  # Cross-platform modules (bash, fonts, garbage, packages, ssh)
  home-manager/              # Home Manager modules (toggleable, custom.* namespace)
    all/                     #   Aliases, Android, Ansible, Base, Bash, Brave, Fastfetch, fnm, Git,
                             #   mpv, pyenv, SSH, Starship, Syncthing, Thunderbird
    linux/                   #   Aliases, Clone Hero, Display profiles, Gaming, HandBrake, KWin tiling,
                             #   LinUtil, Nextcloud, Packages, Plasma config, Shutdown disable outputs,
                             #   Strawberry, Vesktop, VS Code, Window shortcuts
    darwin/                  #   Rectangle
```

## Per-Host Settings

Each host has a `user-settings.nix` that controls system-level decisions:

```nix
{
  username = "myuser";
  hostname = "MYHOST";
  system = "x86_64-linux";       # Architecture
  channel = "stable";            # "stable" or "unstable" nixpkgs
  timeZone = "Europe/Amsterdam";
}
```

The `channel` setting selects between stable and unstable inputs at build time.
It's evaluated per host — you can mix stable and unstable hosts in the same flake.

| Input                     | `"stable"`                             | `"unstable"`                        |
| ------------------------- | -------------------------------------- | ----------------------------------- |
| `nixpkgs`                 | `nixpkgs-stable` (FlakeHub)            | `nixpkgs` (GitHub `nixos-unstable`) |
| `home-manager`            | `home-manager-stable` (follows stable) | `home-manager` (follows unstable)   |
| `nix-darwin` (macOS only) | `nix-darwin-stable`                    | `nix-darwin`                        |

### Switching a host's channel

1. Edit `hosts/<HOST>/user-settings.nix` and set `channel = "unstable";` (or back to `"stable"`).
2. Rebuild the host:

   ```bash
   # NixOS
   sudo nixos-rebuild switch --flake .#<HOST>

   # macOS
   darwin-rebuild switch --flake .#<HOST>
   ```

The flake builder picks the matching nixpkgs / home-manager / nix-darwin
inputs automatically. An invalid value throws a clear error at evaluation
time (see `mkHost` in `flake/hosts.nix`).

## Toggleable Modules

All modules use `lib.mkEnableOption` with the `custom.*` namespace and default to disabled. Import a module and explicitly enable it:

```nix
{
  imports = [ ../../../modules/systems/nixos/printing.nix ];
  custom.sysNixPrinting.enable = true;
}
```

## Determinate Nix

This configuration uses [Determinate Nix](https://determinate.systems/) for:

- **Lazy Trees** — 3x+ faster evaluation, 20x+ less disk usage
- **Parallel Evaluation** — Multi-threaded Nix operations
- **Managed Garbage Collection** — Automatic background cleanup
- **NixOS Integration** — Determinate module included in all NixOS builds

Check version: `nix --version` should show `nix (Determinate Nix X.Y.Z)`

## Useful Flake Commands

```bash
nix flake show          # Show flake outputs
nix flake check         # Validate the flake
nix flake update        # Update all inputs
nix fmt                 # Format nix files (nixfmt-tree)
```

## Resources

- [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
- [nix-community/awesome-nix](https://github.com/nix-community/awesome-nix)
- [m3tam3re/nixcfg](https://code.m3ta.dev/m3tam3re/nixcfg)
