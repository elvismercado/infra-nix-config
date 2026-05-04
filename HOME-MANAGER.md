# Home Manager

Home Manager manages user-level configuration: dotfiles, shell settings, and user applications.

In this repo, Home Manager is integrated as a **system module** on every NixOS and nix-darwin host — it is applied as part of `nixos-rebuild switch` / `darwin-rebuild switch`. Standalone `home-manager switch` is **not** wired up for these hosts; it is reserved for future hosts without a NixOS/darwin system layer (e.g. Ubuntu, Arch) which would be added to the `homeManagerHosts` set in `flake/hosts.nix`.

## Current Hosts

| Host   | System        | Channel | HM Integration |
| ------ | ------------- | ------- | -------------- |
| JIN    | x86_64-linux  | stable  | NixOS module   |
| FENNEC | x86_64-linux  | stable  | NixOS module   |
| EDGE   | x86_64-darwin | stable  | darwin module  |

## Apply

Home Manager config is applied as part of the system rebuild:

```bash
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC
darwin-rebuild switch --flake .#EDGE
```

> There is no standalone `home-manager switch --flake .#<HOST>` for these hosts — `homeManagerHosts` in `flake/hosts.nix` is currently empty. To enable standalone use for a future non-NixOS/non-darwin host, add it to `homeManagerHosts`.

## How It Works

1. `flake/hosts.nix` defines three host sets: `nixosHosts`, `darwinHosts`, and `homeManagerHosts` (the last is for standalone-HM hosts only — currently empty).
2. `flake/nixos.nix` and `flake/darwin.nix` pull in `home-manager.nixosModules.home-manager` / `home-manager.darwinModules.home-manager`, applying each host's `home-manager/` directory as part of the system rebuild.
3. `flake/home.nix` iterates over `homeManagerHosts` and builds a `homeManagerConfiguration` for each — these are exposed as `homeConfigurations.<HOST>` for `home-manager switch`.
4. The nixpkgs channel and system architecture are selected per-host from `user-settings.nix` via `selectNixpkgs`. The Home Manager version is selected per-host via `selectHomeManager` — a `"stable"` host uses `home-manager-stable`, an `"unstable"` host uses `home-manager`.

### What gets passed to modules

Every Home Manager module receives these via `extraSpecialArgs`:

- `inputs` — all flake inputs
- `userSettings` — the host's `user-settings.nix` (`username`, `hostname`, `system`, `channel`, `timeZone`, `uid`, `repoPath`, and optionally `desktopEnvironment`)
- `outputs` — the flake's own outputs

## Toggleable Modules

Home Manager modules use the same `custom.*` namespace pattern. Import and enable in your host's `home-manager/default.nix`:

```nix
{
  imports = [
    ../../../modules/home-manager/all/aliases.nix
    ../../../modules/home-manager/all/bash.nix
    ../../../modules/home-manager/linux/vscode.nix
  ];

  custom.hmAliases.enable = true;
  custom.hmBash.enable = true;
  custom.hmVscode.enable = true;
}
```

### Available Home Manager Modules

**All platforms** (`home-manager/all/`):

| Module                           | Option                      |
| -------------------------------- | --------------------------- |
| `home-manager/all/base.nix`      | `custom.hmBase.enable`      |
|                                  | `custom.hmBase.editor`      |
| `home-manager/all/aliases.nix`   | `custom.hmAliases.enable`   |
| `home-manager/all/android.nix`   | `custom.hmAndroid.enable`   |
| `home-manager/all/ansible.nix`   | `custom.hmAnsible.enable`   |
| `home-manager/all/bash.nix`      | `custom.hmBash.enable`      |
| `home-manager/all/brave.nix`     | `custom.hmBrave.enable`     |
| `home-manager/all/fastfetch.nix` | `custom.hmFastfetch.enable` |
| `home-manager/all/fnm.nix`       | `custom.hmFnm.enable`       |
| `home-manager/all/git.nix`       | `custom.hmGit.enable`       |
| `home-manager/all/mpv.nix`       | `custom.hmMpv.enable`       |

| `home-manager/all/pyenv.nix` | `custom.hmPyenv.enable` |
| `home-manager/all/ssh.nix` | `custom.hmSsh.enable` |
| `home-manager/all/starship.nix` | `custom.hmStarship.enable` |
| | `custom.hmStarship.style` |
| `home-manager/all/syncthing.nix` | `custom.hmSyncthing.enable` |
| `home-manager/all/thunderbird.nix` | `custom.hmThunderbird.enable` |

**Linux — KDE Plasma** (`home-manager/linux/`):

| Module                                            | Option                                   |
| ------------------------------------------------- | ---------------------------------------- |
| `home-manager/linux/aliases.nix`                  | `custom.hmLinuxAliases.enable`           |
|                                                   | `custom.hmAliasesAmdCpu.enable`          |
|                                                   | `custom.hmAliasesNvidiaGpu.enable`       |
| `home-manager/linux/display-profiles.nix`         | `custom.hmDisplayProfiles.enable`        |
| `home-manager/linux/gaming.nix`                   | `custom.hmGaming.enable`                 |
| `home-manager/linux/handbrake.nix`                | `custom.hmHandbrake.enable`              |
| `home-manager/linux/linutil.nix`                  | `custom.hmLinutil.enable`                |
| `home-manager/linux/nextcloud.nix`                | `custom.hmNextcloud.enable`              |
| `home-manager/linux/packages.nix`                 | `custom.hmLinuxPackages.enable`          |
| `home-manager/linux/vscode.nix`                   | `custom.hmVscode.enable`                 |
| `home-manager/linux/plasma-config.nix`            | `custom.hmPlasmaConfig.enable`           |
| `home-manager/linux/sddm-monitor-layout.nix`      | `custom.hmSddmMonitorLayout.enable`      |
| `home-manager/linux/shutdown-disable-outputs.nix` | `custom.hmShutdownDisableOutputs.enable` |
| `home-manager/linux/strawberry.nix`               | `custom.hmStrawberry.enable`             |
| `home-manager/linux/vesktop.nix`                  | `custom.hmVesktop.enable`                |
| `home-manager/linux/window-shortcuts.nix`         | `custom.hmWindowShortcuts.enable`        |

**macOS** (`home-manager/darwin/`):

| Module                              | Option                          |
| ----------------------------------- | ------------------------------- |
| `home-manager/darwin/aliases.nix`   | `custom.hmDarwinAliases.enable` |
| `home-manager/darwin/rectangle.nix` | `custom.hmRectangle.enable`     |

> `systems/shared/ssh-server.nix` (`custom.sysSshServer.enable`) is a **system** module — use it in `configuration/default.nix`, not in `home-manager/default.nix`.

## Adding Home Manager Config for a New Host

Each host already gets a Home Manager entry automatically when registered in `flake/hosts.nix`. You only need to:

1. Create `hosts/<HOSTNAME>/home-manager/default.nix` — imports and enables modules
2. Create `hosts/<HOSTNAME>/home-manager/home.nix` — sets `home.username`, `home.homeDirectory`, `home.stateVersion`

Example `default.nix`:

```nix
{ ... }:
{
  imports = [
    ./home.nix
    ../../../modules/home-manager/all/base.nix
    ../../../modules/home-manager/all/aliases.nix
    ../../../modules/home-manager/all/bash.nix
  ];

  custom.hmBase.enable = true;
  custom.hmAliases.enable = true;
  custom.hmBash.enable = true;
}
```

## Backup and Restore Home Directory

```bash
# Backup (change USER and GROUP to your user)
sudo mkdir -pv /myhomebackup
sudo chown USER:GROUP /myhomebackup
rsync -aAXv --delete --exclude='.cache' ~ /myhomebackup/

# Restore
rsync -aAXv /myhomebackup/ ~
```
