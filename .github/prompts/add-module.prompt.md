---
description: "Scaffold a new Nix module with the custom.*.enable pattern. Use when adding a system or home-manager module."
agent: "agent"
argument-hint: "Module name, scope (nixos/hm-all/hm-linux/etc.), and which hosts to enable it on"
---

Create a new module following the [project conventions](../copilot-instructions.md).

## 1. Gather requirements

If not provided, ask for:

- **Module name** — short, descriptive (e.g., "bluetooth", "gaming")
- **Scope** — where the module lives:
  - `modules/systems/nixos/` — NixOS system module
  - `modules/systems/nixos/<subdir>/` — NixOS module in a subdirectory (e.g., `apps/`, `gaming/`, `memory/`)
  - `modules/systems/darwin/` — nix-darwin system module
  - `modules/systems/shared/` — cross-platform system module
  - `modules/home-manager/all/` — home-manager module for all platforms (Option 1)
  - `modules/home-manager/linux/` — home-manager module for Linux only (or Linux wrapper of a `core/` module)
  - `modules/home-manager/darwin/` — home-manager module for macOS only (or Darwin wrapper of a `core/` module)
  - `modules/home-manager/core/` — internal shared logic for split (Option 2) modules; never imported by hosts directly
  - `modules/apps/darwin/` — darwin app façade (Option 3): owns Homebrew cask + HM config under one toggle
  - `modules/apps/linux/` — linux app façade (Option 3): pulls HM config under the same toggle name
- **Enable option name** — e.g., `custom.sysNixBluetooth.enable` (system), `custom.hmGaming.enable` (home-manager), or `custom.appVscode.enable` (cross-layer façade)
- **One-line purpose** — for the comment header
- **Target hosts** — which hosts to import and enable the module on (e.g., FENNEC, JIN, EDGE)

## 2. Choose placement strategy (home-manager modules only)

For home-manager modules destined for hosts on more than one OS, decide between:

- **Option 1 (default)** — single `modules/home-manager/all/<name>.nix`. Use when home-manager upstream is cross-platform AND no Homebrew-cask conflict on darwin AND behavior is identical on all hosts.
- **Option 2** — `core/<name>.nix` + `linux/<name>.nix` + `darwin/<name>.nix` trio. Required when the package differs per OS (e.g., cask on darwin), runtime semantics diverge, or `pkgs.stdenv.isDarwin` branches in an `all/` file would exceed ~5 lines.
- **Option 3 (app façade)** — add `modules/apps/{darwin,linux}/<name>.nix` on top of an Option 2 trio when the darwin variant needs a Homebrew cask for the binary. The façade owns cask + HM injection under one host-facing toggle (`custom.app<Name>.enable`), so hosts wire the same line on every OS in `configuration/default.nix`. The underlying `custom.hm<Name>.enable` becomes internal.

See [.github/instructions/cross-platform.instructions.md](../instructions/cross-platform.instructions.md) for the full decision tree, code skeletons, and do/don't checklist. Canonical exemplars: [all/git.nix](../../modules/home-manager/all/git.nix) (Option 1), [core/vscode.nix](../../modules/home-manager/core/vscode.nix) + wrappers (Option 2), and [apps/darwin/vscode.nix](../../modules/apps/darwin/vscode.nix) (Option 3).

If Option 2: scaffold all three files. The option (`custom.hm<Name>.enable`) lives ONLY in `core/`. Each wrapper imports `../core/<name>.nix` and adds OS-specific config inside `lib.mkIf cfg.enable`. The `core/` file's header MUST contain: `Internal — do not import from hosts. Imported by linux/<name>.nix and darwin/<name>.nix.`

If Option 3: scaffold the Option 2 trio first, then add `modules/apps/darwin/<name>.nix` and `modules/apps/linux/<name>.nix`. The façade is a **system module** (uses `userSettings.username` from `specialArgs` to inject the HM wrapper into `home-manager.users.<u>.imports`). On darwin, the façade also adds `homebrew.casks = [ "<cask>" ];`.

## 3. Create the module file(s)

Use the standard module template. Follow the existing patterns:

- System modules: [bluetooth.nix](../../modules/systems/nixos/bluetooth.nix)
- Home-manager modules: [gaming.nix](../../modules/home-manager/linux/gaming.nix)

The file must contain:

1. **Comment header** — one-line purpose, brief explanation, and `Usage:` block showing the import path and enable flag
2. **Function arguments** — `{ config, lib, ... }:` (add `pkgs` only if needed)
3. **Options block** — `options.custom.<name>.enable = lib.mkEnableOption "description";`
4. **Config block** — `config = lib.mkIf config.custom.<name>.enable { };` with an empty body

Leave the config body empty — tell the user to fill it in.

When a module option could be derived from existing NixOS config (e.g., swap UUID from `swapDevices`, hostname from `networking.hostName`), make the option optional with a `null` default and auto-derive. Add an assertion for clear errors when auto-derivation fails and no explicit value is provided.

## 4. Wire into host(s)

For each target host:

1. Add the import to `hosts/<HOST>/configuration/default.nix` (system modules **and Option 3 app façades**) or `hosts/<HOST>/home-manager/default.nix` (home-manager modules). For Option 2 home-manager modules, import the OS-specific wrapper (`linux/<name>.nix` or `darwin/<name>.nix`), **never** `core/<name>.nix`. For Option 3, import only the façade from `modules/apps/<os>/<name>.nix` — do not also import the underlying HM module from `home-manager/default.nix`.
2. Add `custom.<name>.enable = true;` under the appropriate category comment
3. Follow the existing category ordering in the file (Nix, Bootloader, Hardware, Memory, System, Display, Peripherals, Services, Apps, Gaming, etc.)
4. If no matching category exists, add a new category comment in a logical position

## 5. Update documentation

Add a row to the correct module table:

- NixOS / shared system modules → `NIXOS.md`
- Home-manager modules → `HOME-MANAGER.md`
- Darwin system modules → `DARWIN.md`

Row format: `| <module-path> | custom.<name>.enable |`

Insert the row in the correct category section of the table, maintaining alphabetical order within the category.

## 6. Remind the user

After scaffolding, print:

> Module scaffolded. Fill in the `config` block in `<path>` with the actual Nix configuration.
