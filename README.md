# Nix Configuration

Declarative system and user configuration for NixOS and macOS using Nix flakes, nix-darwin, and Home Manager.

## System Documentation

- [INSTALL.md](scripts/nixos/INSTALL.md) — Fresh NixOS install guide (partitioning, formatting, flake-based install)
- [NIXOS.md](NIXOS.md) — NixOS system configuration, rebuild commands, adding hosts
- [DARWIN.md](DARWIN.md) — macOS (nix-darwin) configuration, rebuild commands, adding hosts
- [HOME-MANAGER.md](HOME-MANAGER.md) — User-level configuration (dotfiles, apps, shell), works across all systems
- [DISPLAYS.md](DISPLAYS.md) — Shared monitor / KVM / TV topology and per-host display wiring

## Hosts

| Host   | System             | Architecture   | Channel | Docs                               |
| ------ | ------------------ | -------------- | ------- | ---------------------------------- |
| JIN    | NixOS              | x86_64-linux   | stable  | [Hardware](hosts/JIN/README.md)    |
| FENNEC | NixOS              | x86_64-linux   | stable  | [Hardware](hosts/FENNEC/README.md) |
| EDGE   | macOS (nix-darwin) | x86_64-darwin  | stable  | [Hardware](hosts/EDGE/README.md)   |
| LULA   | macOS (nix-darwin) | aarch64-darwin | stable  | [Hardware](hosts/LULA/README.md)   |

## Quick Commands

```bash
# NixOS — rebuild system
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC

# macOS — rebuild system
darwin-rebuild switch --flake .#EDGE
darwin-rebuild switch --flake .#LULA
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
      graphics/              #   AMD, Intel Arc, NVIDIA, nomodeset, nvtop
      input/                 #   Wacom
      memory/                #   zram, earlyoom, hibernation
      mouse/                 #   Logitech
      nix/                   #   Flakes, garbage collection
      security/              #   YubiKey, fprintd
      ssd/                   #   SSD optimisations (fstrim)
      system/                #   Console, fonts, i18n, network tuning, time, user
      bluetooth.nix          #   Bluetooth + A2DP audio
      brave-policies.nix     #   Brave managed policies (debrand + privacy + extensions)
      pipewire.nix           #   PipeWire audio server
    darwin/                  # Darwin-specific modules (Alacritty, Brave policies, Control Center, Dock,
                             #   Finder, fonts, gc, packages, Power, Security, System Preferences, time, Trackpad)
    shared/                  # Cross-platform modules (bash, Brave policies data, fonts, garbage, packages, ssh)
  home-manager/              # Home Manager modules (toggleable, custom.* namespace)
    all/                     #   Aliases, Android, Ansible, Base, Bash, Fastfetch, fnm, Git,
                             #   mpv, pyenv, SSH, Starship
    core/                    #   Shared cross-platform logic for split (Option 2) modules.
                             #   Internal — never imported by hosts; only by linux/ and darwin/ wrappers.
                             #   (Brave, Discord, HandBrake, LibreWolf, Nextcloud, Syncthing,
                             #   Thunderbird, VS Code)
    linux/                   #   Aliases, Clone Hero, Display profiles, Gaming, KWin tiling,
                             #   LinUtil, Packages, Plasma config, Shutdown disable outputs,
                             #   Strawberry, Window shortcuts, plus wrappers (Brave, Discord,
                             #   HandBrake, LibreWolf, Nextcloud, Syncthing, Thunderbird, VS Code)
    darwin/                  #   Rectangle, plus wrappers (Brave, Discord, HandBrake, LibreWolf,
                             #   Nextcloud, Syncthing, Thunderbird, VS Code)
  apps/                      # Cross-layer app façades (single toggle owns both
                             #   the binary delivery and the matching home-manager
                             #   config). Imported from configuration/, NOT home-manager/.
    darwin/                  #   Beeper, Brave, Discord, Ferdium, HandBrake, Insync, LibreOffice,
                             #   LibreWolf, LocalSend, Moonlight, Mullvad VPN, Nextcloud,
                             #   ProtonMail Bridge, Raspberry Pi Imager, Shotcut, Signal,
                             #   Spotify, Steam, Sweet Home 3D, Syncthing, Thunderbird, VS Code,
                             #   Yubico Authenticator (cask + HM config)
    linux/                   #   Beeper, Brave, Discord, Ferdium, HandBrake, Insync, LibreOffice,
                             #   LibreWolf, LocalSend, Moonlight, Mullvad VPN, Nextcloud,
                             #   ProtonMail Bridge, Raspberry Pi Imager, Shotcut, Signal,
                             #   Spotify, Steam, Sweet Home 3D, Syncthing, Thunderbird, VS Code,
                             #   Yubico Authenticator (HM injection; Steam and Mullvad VPN
                             #   are system-level)
```

## Private Sibling Repo

A handful of host-identifying fields (Syncthing device IDs, per-peer LAN
addresses) live in a separate private repo,
[`elvismercado/nix-config-private`](https://github.com/elvismercado/nix-config-private),
cloned as a sibling folder on disk:

```
~/git/
├── nix-config/              # this repo (public)
└── nix-config-private/      # sibling (private; same shape under hosts/)
```

The flake loader ([flake/metadata.nix](flake/metadata.nix)) auto-discovers
the sibling and merges its per-host overrides on top of the public
`hosts/<HOST>/metadata.nix` stubs via `lib.recursiveUpdate`. When the
sibling is absent (CI, outside contributors, a fresh checkout), the
merge is a no-op — the Syncthing peer map ends up empty and
`nix flake check` still passes. Managed hosts clone both repos as
siblings during install.

A multi-root VS Code workspace [`nix-config.code-workspace`](nix-config.code-workspace)
at the repo root opens both folders in one window when the sibling is
present.

## PII & Secrets Discipline

Notes-to-self distilled from the Round 15 PII audit (see [TODO.md](TODO.md)).
Single-maintainer repo, so this section is the entire backstop: no
`SECURITY.md`, no `CONTRIBUTING.md`.

### The split

Host-identifying fields (Syncthing device IDs, per-peer LAN addresses,
`timeZone`) live in [`nix-config-private`](https://github.com/elvismercado/nix-config-private)
and are merged in by the flake loader. The public repo carries structure
and non-identifying config. See [Private Sibling Repo](#private-sibling-repo)
for the mechanism.

### `.gitignore` guards

The public [`.gitignore`](.gitignore) blocks the common shapes of
accidentally-committed local state:

- `*.local.nix` (with a `!*.example.local.nix` carve-out for committed templates)
- `secrets/`
- `.env`, `.env.*`
- `*.age`, `*.gpg`
- `**/INSTALL-REPORT.md`

### Accepted exposures

The public tree deliberately exposes:

- The set of installed apps, which implies accounts with their respective
  cloud services (Nextcloud, Google Drive via Insync, Proton Mail, Mullvad
  VPN, Syncthing). No URLs, tokens, account IDs, or device IDs ride along.
- Each host's `channel` choice and hardware class strings in per-host
  READMEs.

Full reasoning lives in `TODO.md` Round 15 → `P3 — Architecture & Convention`
→ "Cloud-service app intent" entry.

### Pre-push checklist

Before pushing to the public remote, run the three probes from
`TODO.md` Round 15 P3 "Git history may contain pre-cleanup leaks":

```bash
git log --all -S "192.168" --oneline
git log --all -S "<one syncthing ID prefix>" --oneline
git log --all --grep -iE "password|secret|token|credential"
```

If a probe surfaces a real value in old commits, **rotate it** (e.g. the
Syncthing device-ID rotation procedure in the Backlog → Round 15
follow-ups). `git filter-repo` rewrite is declined: force-push doesn't
unpublish what is already cloned or cached, and breaks downstream forks.

## Per-Host Settings

Each host has a `user-settings.nix` that controls system-level decisions:

```nix
{
  username = "myuser";
  hostname = "MYHOST";
  system = "x86_64-linux";       # Architecture
  channel = "stable";            # "stable" or "unstable" nixpkgs
  # timeZone = "Etc/UTC"; # optional — typically set in nix-config-private; default Etc/UTC
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
