# Infra Nix Configuration

Declarative system and user configuration using Nix flakes. NixOS manages the
full Linux system, nix-darwin manages macOS, and standalone Home Manager manages
user configuration and Nix packages on other Linux distributions.

## System Documentation

- [INSTALL.md](scripts/nixos/INSTALL.md) — Fresh NixOS install guide (partitioning, formatting, flake-based install)
- [NIXOS.md](NIXOS.md) — NixOS system configuration, rebuild commands, adding hosts
- [DARWIN.md](DARWIN.md) — macOS (nix-darwin) configuration, rebuild commands, adding hosts
- [HOME-MANAGER.md](HOME-MANAGER.md) — User-level configuration and standalone Linux setup
- [DISPLAYS.md](DISPLAYS.md) — Shared monitor / KVM / TV topology and per-host display wiring

## Hosts

| Host   | System             | Architecture  | Channel | Docs                               |
| ------ | ------------------ | ------------- | ------- | ---------------------------------- |
| JIN    | NixOS              | x86_64-linux  | stable  | [Hardware](hosts/JIN/README.md)    |
| FENNEC | NixOS              | x86_64-linux  | stable  | [Hardware](hosts/FENNEC/README.md) |
| LULA   | NixOS              | x86_64-linux  | stable  | [Hardware](hosts/LULA/README.md)   |
| EDGE   | macOS (nix-darwin) | x86_64-darwin | stable  | [Hardware](hosts/EDGE/README.md)   |

No standalone Home Manager hosts are registered yet. Add non-NixOS Linux hosts
to `homeManagerHosts` in `flake/hosts.nix`.

## Quick Commands

```bash
# NixOS — rebuild system
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC
sudo nixos-rebuild switch --flake .#LULA

# macOS — rebuild system
darwin-rebuild switch --flake .#EDGE

# Other Linux distributions — apply standalone Home Manager
home-manager switch --flake .#<HOST>
```

> NixOS and macOS hosts apply Home Manager as part of their system rebuild.
> Standalone `home-manager switch` is only for hosts registered in
> `homeManagerHosts`.

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
git clone https://github.com/elvismercado/infra-nix-config ~/git/infra-nix-config
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
      apps/                  #   Coolercontrol, embedded, libvirtd, sunshine
      bootloader/            #   GRUB, systemd-boot, Plymouth, GRUB/Plymouth themes
      cpu/amd/               #   AMD base, Ryzen, P-State, Zenpower, zen-kernel, mitigations-off + CPU profiles (3900X, 5900X)
      cpu/intel/             #   Intel base + CPU profiles (Tiger Lake i5-1135G7)
      desktop_environment/   #   KDE Plasma, COSMIC
      display_manager/       #   SDDM, SDDM monitor layout, SDDM input config
      graphics/              #   AMD, Intel Arc, Intel Iris Xe, NVIDIA, nomodeset, nvtop
      input/                 #   Wacom
      laptop/                #   Lenovo ThinkPad T14 Gen 2 (Intel) chassis quirks
      memory/                #   zram, earlyoom, hibernation
      mouse/                 #   Logitech
      network/               #   Wake-on-LAN, Tailscale
      nix/                   #   Flakes, garbage collection
      power/                 #   power-profiles-daemon
      security/              #   YubiKey, fprintd
      ssd/                   #   SSD optimisations (fstrim)
      system/                #   Console, fonts, i18n, network tuning, time, user
      bluetooth.nix          #   Bluetooth + A2DP audio
      brave-policies.nix     #   Brave managed policies (debrand + privacy + extensions)
      pipewire.nix           #   PipeWire audio server
    darwin/                  # Darwin-specific modules (Alacritty, Brave policies, Control Center, Dock,
                             #   Finder, fonts, gc, packages, Power, Security, System Preferences, Tailscale, time, Trackpad)
    shared/                  # Cross-platform modules (bash, Brave policies data, fonts, garbage, packages, ssh)
  home-manager/              # Home Manager modules (toggleable, custom.* namespace)
    all/                     #   Aliases, Android, Ansible, Base, Bash, Fastfetch, fnm, Git,
                             #   mpv, pyenv, SSH, Starship
    core/                    #   Shared cross-platform logic for split (Option 2) modules.
                             #   Internal — never imported by hosts; only by linux/ and darwin/ wrappers.
                             #   (Brave, Discord, HandBrake, LibreWolf, Nextcloud, Syncthing,
                             #   Thunderbird, VS Code)
    linux/                   #   Aliases, Clone Hero, Display profiles, Gaming, KWin tiling,
                 #   LinUtil, NixOS diagnostics, Packages, Plasma config, Shutdown disable outputs,
                             #   Strawberry, Trayscale, Window shortcuts, plus wrappers (Brave, Discord,
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

## Private Companion Repo

A handful of host-identifying fields (Syncthing device IDs, per-peer LAN
addresses, per-host `timeZone` / `language` / `regionalFormat`) live in
a separate private repo,
[`elvismercado/infra-nix-config-private`](https://github.com/elvismercado/infra-nix-config-private).

The companion has two distinct integration paths:

- **Private flake input:** `flake.nix` declares the repository as the
  `flake = false` input `private` using the GitHub URL scheme. Per-host user
  settings, Syncthing metadata, and low-sensitivity secrets are fetched from
  GitHub, so the invoking user must run `gh auth login` once. The repository's `switch*` aliases inject
  `--option access-tokens "github.com=$(gh auth token)"` for each rebuild.
- **Optional local sibling:** provides the normal editing and sync workflow for
  private files. Rebuilds consume the pinned GitHub input, not uncommitted files
  from this checkout.

```
~/git/
├── infra-nix-config/          # this repo (public)
└── infra-nix-config-private/  # optional local companion
```

Private changes must be committed and pushed before a rebuild can consume
them. An ordinary `switch` uses the GitHub revision pinned in `flake.lock`; it
does not read uncommitted files from the local sibling or refresh that pin.
A local empty stub does not satisfy or override the GitHub input. Offline
private-input substitution remains tracked in [TODO.md](TODO.md).

Publish private changes in this order:

1. Edit, commit, and push `infra-nix-config-private`.
2. From `infra-nix-config`, run `switchbumpprivate`. It updates only the
   `private` input, then commits and pushes the resulting `flake.lock` change.
3. On other hosts, run `switchpull` to fast-forward both repositories and
   refresh the local private lock entry, then run the appropriate build or
   switch command.

Clone the optional companion with:

```bash
cd ~/git
gh repo clone elvismercado/infra-nix-config-private
```

The multi-root workspace [infra-nix-config.code-workspace](infra-nix-config.code-workspace)
opens both repositories when the companion is present.

## PII & Secrets Discipline

Notes-to-self on what stays public vs private and the hygiene that keeps
the split working. Single-maintainer repo, so this section is the entire
backstop: no `SECURITY.md`, no `CONTRIBUTING.md`.

### The split

Host-identifying fields (Syncthing device IDs, per-peer LAN addresses,
`timeZone`) live in [`infra-nix-config-private`](https://github.com/elvismercado/infra-nix-config-private)
and are merged in by the flake loader. The public repo carries structure
and non-identifying config. See [Private Companion Repo](#private-companion-repo)
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

### Pre-push checklist

Before pushing to the public remote, run these probes for leaks that may
have landed in commits:

```bash
git log --all -S "192.168" --oneline
git log --all -S "<one syncthing ID prefix>" --oneline
git log --all --grep -iE "password|secret|token|credential"
```

If a probe surfaces a real value in old commits, **rotate it** (e.g.
regenerate a Syncthing device identity by deleting `cert.pem` + `key.pem`
and restarting, then update `infra-nix-config-private`). `git filter-repo`
rewrite is declined: force-push doesn't unpublish what is already cloned
or cached, and breaks downstream forks.

## Per-Host Settings

Each host has a `user-settings.nix` that controls system-level decisions:

```nix
{
  username = "myuser";
  hostname = "MYHOST";
  system = "x86_64-linux";       # Architecture
  channel = "stable";            # "stable" or "unstable" nixpkgs
  # timeZone = "Etc/UTC"; # optional — typically set in infra-nix-config-private; default Etc/UTC
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
