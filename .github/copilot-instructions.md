# Nix Configuration — Copilot Instructions

## Project Structure

- `flake.nix` + `flake/` — Flake entry, builders for darwinConfigurations, nixosConfigurations, homeConfigurations
- `hosts/<HOSTNAME>/` — Per-host config: `user-settings.nix`, `configuration/`, `home-manager/`
- `modules/home-manager/` — Shared home-manager modules (`all/`, `core/`, `darwin/`, `linux/`)
- `modules/systems/` — System-level modules (`darwin/`, `nixos/`, `shared/`)
- `scripts/nixos/install.sh` and `scripts/nixos/postinstall.sh` are the source of truth for the NixOS install and post-install workflows. `scripts/nixos/INSTALL.md` documents the same steps and must stay aligned with both scripts.

## Platform Scope

This repository manages **NixOS** and **macOS (nix-darwin)** hosts. **Windows is out of scope** — declarative Windows configuration lives in a separate `elvismercado/windows-config` repository. WSL distributions running inside Windows are treated as Linux and may live here as standalone home-manager hosts.

## Custom Module Convention

All modules use a `custom.*.enable` toggle pattern with a **scope prefix**:

- `hm*` — home-manager modules (e.g., `custom.hmBash`, `custom.hmBrave`)
- `sys*` — shared system modules (e.g., `custom.sysPackages`, `custom.sysFonts`)
- `sysDar*` — darwin-only system modules (e.g., `custom.sysDarDock`, `custom.sysDarFinder`)
- `sysNix*` — NixOS-only system modules (e.g., `custom.sysNixBluetooth`, `custom.sysNixPlymouth`)
- `app*` — cross-layer app façade modules that own both the OS-level binary delivery (Homebrew cask or nixpkgs) and the matching home-manager config (e.g., `custom.appVscode`). See "App Modules (Cross-Layer Façade)" below.

```nix
{
  options.custom.<prefix><Name>.enable = lib.mkEnableOption "description";
  config = lib.mkIf config.custom.<prefix><Name>.enable { ... };
}
```

The `mkEnableOption` description should summarise _what the module configures_ (matching the header comment), not restate the option name. Avoid `"enables foo"` — prefer e.g. `"Brave browser with KDE Plasma integration"` or `"Bash shell with history, completion, and login hooks"`.

Modules are imported in the host's `home-manager/default.nix` or `configuration/default.nix`, then explicitly enabled with `custom.<prefix><Name>.enable = true`.

New modules should include a comment header with: one-line purpose, brief explanation, and a `Usage:` block showing the import path and enable flag.

When a module option could be derived from existing NixOS config (e.g., swap UUID from `swapDevices`, hostname from `networking.hostName`), make the option optional with a `null` default and auto-derive. Add an assertion for clear errors when auto-derivation fails and no explicit value is provided.

## Module Placement

- `modules/home-manager/all/` — Cross-platform modules that work on every host without OS gating (e.g., `git.nix`, `bash.nix`, `mpv.nix`). Hosts may import freely.
- `modules/home-manager/linux/` — Linux-only modules **OR** Linux wrappers around a `core/` module (e.g., `vesktop.nix`, `gaming.nix`, `plasma-config.nix`). Hosts may import.
- `modules/home-manager/darwin/` — macOS-only modules **OR** Darwin wrappers around a `core/` module (e.g., `rectangle.nix`). Hosts may import.
- `modules/home-manager/core/` — **Shared logic for split (Option 2) modules. Hosts MUST NOT import directly.** Only files in `linux/` and `darwin/` may import from `core/`. See "Cross-Platform Module Strategy" below.
- `modules/systems/nixos/` — NixOS system-level modules
- `modules/systems/darwin/` — nix-darwin system-level modules
- `modules/systems/shared/` — System modules shared between NixOS and darwin
- `modules/apps/` — Cross-layer app façades (`darwin/`, `linux/`). Each façade owns the binary (cask or nixpkgs) **and** wires the matching home-manager config under one toggle. Imported from `hosts/<HOST>/configuration/default.nix`. See "App Modules (Cross-Layer Façade)" below.

When an app is cross-platform in nixpkgs but only used on Linux hosts in this repo (e.g., Discord/Vesktop — macOS uses Homebrew cask), place it in `linux/`.

## Cross-Platform Module Strategy

When a home-manager module needs to work on both Linux and macOS, prefer the simplest viable option. Escalate only when forced.

**Option 1 — single `all/` module (default).** Use when home-manager upstream `programs.<x>` is cross-platform, behavior is identical on every host, and there is no nixpkgs-vs-Homebrew-cask conflict on darwin. Example: `all/git.nix`.

**Option 2 — `core/` + `linux/` + `darwin/` trio.** Use when ANY of the following is true:

- The package differs per OS (e.g., one OS uses a Homebrew cask, the other uses nixpkgs).
- Runtime semantics differ in a way that doesn't fit a single file cleanly.
- An `all/` module starts accumulating `pkgs.stdenv.isDarwin` branches longer than ~5 lines.

Rules for Option 2:

- The `core/<name>.nix` file defines THE option (`custom.hm<Name>.enable`) — there is one option, never per-OS variants.
- The `core/` file holds all shared config (settings, extensions, helpers, assertions).
- `linux/<name>.nix` and `darwin/<name>.nix` import the core file and add only OS-specific config inside `lib.mkIf cfg.enable`.
- File header on `core/<name>.nix` MUST state: "Internal — do not import from hosts. Imported by `linux/<name>.nix` and `darwin/<name>.nix`."
- Hosts always import the `linux/` or `darwin/` wrapper, never the `core/` file.

See [.github/instructions/cross-platform.instructions.md](instructions/cross-platform.instructions.md) for the full pattern, code skeletons, and the do/don't checklist. Canonical exemplars: `all/git.nix` (Option 1) and `core/vscode.nix` + `linux/vscode.nix` + `darwin/vscode.nix` (Option 2).

## App Modules (Cross-Layer Façade)

When an app's binary lives in a different layer than its config — typically a Homebrew cask on darwin (system layer) plus declarative settings via home-manager (user layer) — a single home-manager toggle is not enough: HM cannot reach `homebrew.casks`. Wire such apps through a **cross-layer façade** under `modules/apps/<os>/<name>.nix` instead.

Rules:

- The façade is a **system module** (it lives in `modules/apps/<os>/` and is imported from `hosts/<HOST>/configuration/default.nix`).
- It declares ONE option: `custom.app<Name>.enable`.
- On enable, it owns:
  1. Binary delivery — e.g., `homebrew.casks` on darwin, or `home-manager.users.<u>.home.packages` / a flip of an HM toggle on Linux.
  2. HM config injection — imports the matching `modules/home-manager/<linux|darwin>/<name>.nix` wrapper into HM scope and flips its `custom.hm<Name>.enable`.
- Same option name on every host (`custom.appVscode.enable = true;` looks identical on JIN, FENNEC, EDGE).
- The underlying `custom.hm<Name>.enable` becomes **internal** — hosts should not set it directly when an `app<Name>` façade exists.
- On NixOS, the façade may be a thin forwarder (just imports + flips HM enable). That's accepted as the price of OS-symmetric host wiring.

Use this pattern only when binary and config genuinely cross layer boundaries. Pure-HM apps (`mpv`) stay `hm*`; pure-system apps (`bluetooth`, `dock`) stay `sys*`. Canonical exemplar: `modules/apps/{darwin,linux}/vscode.nix`.

## Host Wiring

- `default.nix` is the import entry point for both `configuration/` and `home-manager/`
- `user-settings.nix` provides `username`, `hostname`, `system`, `channel`, `uid`, `repoPath` (relative to `$HOME`), and optionally `timeZone`, `language`, `regionalFormat`, and `desktopEnvironment`. `timeZone`, `language`, and `regionalFormat` are treated as PII (regional/cultural fingerprint) and typically live in the `nix-config-private/hosts/<HOST>/user-settings.nix` overlay merged in by `flake/hosts.nix`; the time modules fall back to `Etc/UTC` via `userSettings.timeZone or "Etc/UTC"` when no value is provided, and the i18n modules fall back to `"en-GB"` via `userSettings.language or "en-GB"` (with `regionalFormat` defaulting to `language` when unset). Both `language` and `regionalFormat` use BCP 47 dash form (e.g. `"en-GB"`, `"es-ES"`, `"nl-NL"`). `desktopEnvironment` (e.g. `"kde-plasma"`) is consumed by `brave.nix` and read elsewhere via `userSettings.desktopEnvironment or null`. NixOS hosts wire timezone/i18n with `custom.sysNixTimezone.enable = true;` and `custom.sysNixI18n.enable = true;`; darwin hosts wire them with `custom.sysDarTimezone.enable = true;` and `custom.sysDarI18n.enable = true;`.
- Modules receive `userSettings` via `extraSpecialArgs` (home-manager) or `specialArgs` (system)
- Host-identifying values (hostname, computer name, SMB name, etc.) must use `userSettings.hostname` — never hardcode the hostname string

### Home-Manager Integration

NixOS and darwin hosts use home-manager as a system module (`nixosModules.home-manager` / `darwinModules.home-manager`). This sets `submoduleSupport.enable = true`, which means:

- `programs.home-manager.enable = true` is a **no-op** — it does not install the CLI
- Home-manager config is applied via `nixos-rebuild switch` / `darwin-rebuild switch`, not `home-manager switch`
- `homeManagerHosts` in `flake/hosts.nix` is reserved for standalone hosts (e.g., Arch Linux) without system module integration

## nix-darwin vs NixOS

These are different systems with different option sets. Do not assume NixOS options exist on nix-darwin:

- **NixOS-only**: `initialPassword`, `createHome`, `isNormalUser`, `extraGroups`, `nix.gc.automatic`, `nix.optimise.automatic`
- **nix-darwin-only**: `system.primaryUser`, `users.knownUsers`, `homebrew.*`
- **Both**: `users.users.<name>.uid`, `users.users.<name>.home`, `users.users.<name>.shell`, `environment.shells`, `environment.variables`

## Determinate Nix

EDGE uses Determinate Nix installer, which manages its own daemon and GC. Set `nix.enable = false` — do not configure `nix.gc.*` or `nix.optimise.*` on these hosts.

## Channel Selection

Per-host `user-settings.nix` has a `channel` field (`"stable"` or `"unstable"`). The flake selects the matching nixpkgs, nix-darwin, and home-manager inputs accordingly.

## Package Install Priority (macOS)

1. **home-manager** (`home.packages`, `programs.*`) — CLI tools and configured programs
2. **nix-darwin** (`environment.systemPackages`) — system-level packages
3. **Homebrew** (`homebrew.brews` / `homebrew.casks`) — GUI apps and formulae without nixpkgs equivalents
4. **Mac App Store** (`homebrew.masApps`) — App Store-only apps (e.g., WireGuard)

Do not install GUI apps via nixpkgs on macOS — they lack Spotlight indexing, Gatekeeper integration, and auto-update. Use `homebrew.casks` instead. Never use both nixpkgs and a homebrew cask for the same app.

**Exception — cask + module coexistence:** A home-manager module that sets `programs.<app>.package = null` only writes config files (e.g., `~/Library/Application Support/.../settings.json`) and does NOT install a binary. Such a module may coexist with a Homebrew cask: cask provides the app binary, module provides declarative config. This is the canonical Option 2 pattern for apps like VS Code on darwin (see Cross-Platform Module Strategy).

## Workflow

- When asked to plan: present the plan and wait for explicit approval before implementing
- When creating new modules: follow the `custom.*.enable` pattern above
- When adding a module to a host: import in `default.nix` AND set `custom.*.enable = true`
- When adding new modules or hosts: update the module tables in `NIXOS.md`, `HOME-MANAGER.md`, or `DARWIN.md`, the hosts tables in `README.md`, and the directory listing block under "Repository Structure" in `README.md` as part of the same change
