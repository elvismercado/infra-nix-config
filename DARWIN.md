# macOS (nix-darwin)

macOS system configuration is managed through `flake/darwin.nix` using [nix-darwin](https://github.com/nix-darwin/nix-darwin). Each Darwin host gets a system build using `nix-darwin.lib.darwinSystem`.

## Current Hosts

| Host | Architecture  | Channel | User  | Hardware                       |
| ---- | ------------- | ------- | ----- | ------------------------------ |
| EDGE | x86_64-darwin | stable  | elvis | 2018 MacBook Pro 15", Intel i9 |

### Intel Darwin compatibility

Nixpkgs 26.05 is the final release that supports `x86_64-darwin`, with package
support maintained through the end of 2026. EDGE therefore uses dedicated
26.05 Nixpkgs, nix-darwin, and Home Manager inputs even though its host channel
remains `"stable"`. Linux stable hosts continue following the current stable
release, and Apple Silicon Darwin hosts may continue using current stable or
unstable inputs.

## Rebuild

Rebuild the system configuration from the flake:

```bash
# Rebuild using the host's flake configuration
darwin-rebuild switch --flake .#EDGE
```

## How It Works

1. Hosts are registered in `flake/hosts.nix` under `darwinHosts`
2. `flake/darwin.nix` iterates over all Darwin hosts and builds a `darwinSystem` for each
3. The nixpkgs channel (stable/unstable) is selected per-host based on `channel` in `user-settings.nix` via `selectNixpkgs`; `x86_64-darwin` hosts instead use the dedicated 26.05 compatibility stack
4. `nixpkgs.source` is set to the selected channel's `outPath`, ensuring all packages come from the right branch
5. The Home Manager and nix-darwin versions follow the same per-host selection, including the Intel Darwin 26.05 compatibility stack
6. Home Manager is integrated as a nix-darwin module for system rebuilds

### What gets passed to modules

Every Darwin module receives these via `specialArgs`:

- `inputs` — all flake inputs (access `inputs.home-manager`, etc.)
- `userSettings` — the host's `user-settings.nix` (`username`, `hostname`, `system`, `channel`; optional `timeZone`)
- `outputs` — the flake's own outputs

## Determinate Nix on macOS

On macOS, the Nix daemon is managed by the Determinate Nix installer (not by nix-darwin). Darwin hosts should set `nix.enable = false` in their configuration to avoid conflicts — this means `nix.settings` is a no-op and modules like `enable-flakes.nix` are not needed.

## Toggleable Modules

Modules use the same `custom.*` namespace pattern as NixOS. Import and enable in your host's `configuration/default.nix`:

```nix
{
  imports = [
    ../../../modules/systems/darwin/alacritty.nix
  ];

  custom.sysDarAlacritty.enable = true;
}
```

### Available Darwin Modules

| Module                                  | Option                                                                  |
| --------------------------------------- | ----------------------------------------------------------------------- |
| `systems/darwin/alacritty.nix`          | `custom.sysDarAlacritty.enable`                                         |
| `systems/darwin/brave-policies.nix`     | `custom.sysBravePolicies.enable` (managed via `custom.appBrave.enable`) |
| `systems/darwin/control-center.nix`     | `custom.sysDarControlCenter.enable`                                     |
| `systems/darwin/dock.nix`               | `custom.sysDarDock.enable`                                              |
| `systems/darwin/finder.nix`             | `custom.sysDarFinder.enable`                                            |
| `systems/darwin/fonts.nix`              | `custom.sysFonts.enable`                                                |
| `systems/darwin/garbage.nix`            | `custom.sysGc.enable`                                                   |
| `systems/darwin/i18n.nix`               | `custom.sysDarI18n.enable`                                              |
| `systems/darwin/packages.nix`           | `custom.sysPackages.enable`                                             |
| `systems/darwin/power.nix`              | `custom.sysDarPower.enable`                                             |
| `systems/darwin/security.nix`           | `custom.sysDarSecurity.enable`                                          |
| `systems/darwin/system-preferences.nix` | `custom.sysDarPreferences.enable`                                       |
| `systems/darwin/tailscale.nix`          | `custom.sysDarTailscale.enable`                                         |
| `systems/darwin/time.nix`               | `custom.sysDarTimezone.enable`                                          |
| `systems/darwin/trackpad.nix`           | `custom.sysDarTrackpad.enable`                                          |
| **Shared** (cross-platform)             |                                                                         |
| `systems/shared/bash.nix`               | `custom.sysBashCompletion.enable`                                       |
| `systems/shared/fonts.nix`              | `custom.sysFonts.enable`                                                |
| `systems/shared/packages.nix`           | `custom.sysPackages.enable`                                             |
| `systems/shared/ssh-server.nix`         | `custom.sysSshServer.enable`                                            |

> Darwin wrapper modules (e.g. `darwin/garbage.nix`) import the shared module and add Darwin-specific settings. Import the `darwin/` file, not the `shared/` file directly.

## Installing Nix on macOS

This configuration uses [Determinate Nix](https://determinate.systems/). Install with:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
```

After installation, clone the repo and run `darwin-rebuild switch`.

## Adding a New Darwin Host

1. Create the host directory:

   ```
   hosts/<HOSTNAME>/
     user-settings.nix
     configuration/
       default.nix
       configuration.nix
       homebrew.nix       # recommended: extract `homebrew = { ... }` here (see hosts/EDGE)
       user.nix
     home-manager/
       default.nix
       home.nix
   ```

2. Define `user-settings.nix`:

   ```nix
   {
     username = "myuser"; # username or name of the system user
     hostname = "MYHOST"; # description / hostname
     system = "aarch64-darwin"; # or "x86_64-darwin" for Intel Macs
     channel = "stable"; # "stable" or "unstable"
    # timeZone = "Etc/UTC"; # optional — typically set in the infra-nix-config-private overlay; default Etc/UTC
     uid = 501; # required for users.knownUsers — find with `id -u <username>`
    repoPath = "git/infra-nix-config"; # relative to $HOME
     desktopEnvironment = null; # macOS — DE managed by the OS
   }
   ```

3. Register the host in `flake/hosts.nix`:

   ```nix
   darwinHosts = {
     MYHOST = mkHost "MYHOST";
   };
   ```

4. Rebuild:

   ```bash
   darwin-rebuild switch --flake .#MYHOST
   ```
