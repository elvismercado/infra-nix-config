---
applyTo: "modules/home-manager/all/**,modules/home-manager/core/**,modules/home-manager/linux/**,modules/home-manager/darwin/**,modules/systems/shared/**,modules/apps/**,hosts/*/home-manager/**,hosts/*/configuration/**"
description: "Cross-platform module placement and the Option 1 / Option 2 / Option 3 (app façade) pattern"
---

## Cross-Platform Module Strategy

### Repository scope

This repo manages **NixOS** and **macOS (nix-darwin)** hosts. Windows is **out of scope** — declarative Windows configuration lives in the separate `elvismercado/windows-config` repository. WSL distributions running inside Windows are treated as Linux and may live here as standalone home-manager hosts.

Within scope, every home-manager module falls into one of these placements:

| Folder                         | Purpose                                                 | Hosts may import? |
| ------------------------------ | ------------------------------------------------------- | ----------------- |
| `modules/home-manager/all/`    | Module works on every host without OS gating            | ✅                |
| `modules/home-manager/linux/`  | Linux-only module **OR** Linux wrapper around `core/`   | ✅                |
| `modules/home-manager/darwin/` | Darwin-only module **OR** Darwin wrapper around `core/` | ✅                |
| `modules/home-manager/core/`   | Shared logic for split (Option 2) modules               | ❌ NEVER          |

### Decision tree

When adding a new home-manager module, walk this in order:

1. **Is the app Linux-only or macOS-only by nature?** (e.g., KDE Plasma config, Rectangle window manager) → place in `linux/` or `darwin/`. Done.
2. **Is the app cross-platform but only used on one OS in this repo?** (e.g., Discord/Vesktop on Linux because macOS uses a Homebrew cask) → place in `linux/` or `darwin/`. Document the reason in the file header.
3. **Is the app cross-platform AND used on hosts of both OS families?**
   - Does home-manager upstream `programs.<x>` work cross-platform AND there is no Homebrew-cask conflict on darwin AND behavior is identical?  
     → **Option 1**: single `all/<name>.nix`. Done.
   - Otherwise (different package per OS, semantics diverge, or `pkgs.stdenv.isDarwin` branches would exceed ~5 lines):  
     → **Option 2**: `core/<name>.nix` + `linux/<name>.nix` + `darwin/<name>.nix`.
4. **Does the darwin variant of an Option 2 module need its binary from a Homebrew cask** (so the HM module sets `programs.<x>.package = null` and a separate `homebrew.casks` entry would otherwise have to be wired by hand on every host)?  
   → **Option 3**: add an app façade under `modules/apps/{darwin,linux}/<name>.nix`. The Option 2 trio stays in place but its `custom.hm<Name>.enable` becomes internal; hosts only set `custom.app<Name>.enable`.

### Option 1 — single `all/` module

The default. Identical wiring on every host.

**Canonical exemplar:** [modules/home-manager/all/mpv.nix](../../modules/home-manager/all/mpv.nix).

```nix
# modules/home-manager/all/<name>.nix
# <one-line purpose>
#
# <brief explanation>
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/<name>.nix ];
#   custom.hm<Name>.enable = true;

{ config, lib, ... }:
{
  options.custom.hm<Name>.enable = lib.mkEnableOption "<description>";

  config = lib.mkIf config.custom.hm<Name>.enable {
    programs.<x>.enable = true;
    # Any shared settings here.
  };
}
```

**Hosts wire identically:**

```nix
# hosts/<HOST>/home-manager/default.nix
imports = [ ../../../modules/home-manager/all/<name>.nix ];
custom.hm<Name>.enable = true;
```

### Option 2 — `core/` + `linux/` + `darwin/` trio

When OS divergence forces a split. **Single user-facing option** (defined in `core/`) regardless of how many wrappers exist.

**Canonical exemplar:** VS Code — [core/vscode.nix](../../modules/home-manager/core/vscode.nix), [linux/vscode.nix](../../modules/home-manager/linux/vscode.nix), [darwin/vscode.nix](../../modules/home-manager/darwin/vscode.nix).

#### `core/<name>.nix`

```nix
# modules/home-manager/core/<name>.nix
# <one-line purpose> — shared cross-platform core
#
# Internal — do not import from hosts. Imported by `linux/<name>.nix` and `darwin/<name>.nix`.
# Hosts wire by importing the OS-specific wrapper instead.

{ config, lib, ... }:
{
  options.custom.hm<Name>.enable = lib.mkEnableOption "<description>";

  config = lib.mkIf config.custom.hm<Name>.enable {
    # All shared config: settings, extensions, plugins, helpers.
    programs.<x> = {
      enable = true;
      # ... cross-platform settings ...
    };
  };
}
```

#### `linux/<name>.nix`

```nix
# modules/home-manager/linux/<name>.nix
# Linux wrapper for the cross-platform <name> core module.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/<name>.nix ];
#   custom.hm<Name>.enable = true;

{ config, lib, ... }:
{
  imports = [ ../core/<name>.nix ];

  config = lib.mkIf config.custom.hm<Name>.enable {
    # Linux-only additions — often empty if the core module's defaults work as-is.
  };
}
```

#### `darwin/<name>.nix`

```nix
# modules/home-manager/darwin/<name>.nix
# Darwin wrapper for the cross-platform <name> core module.
#
# Binary is provided by the Homebrew cask `<cask-name>` (see hosts/<HOST>/configuration/homebrew.nix);
# this module manages config only.
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/<name>.nix ];
#   custom.hm<Name>.enable = true;

{ config, lib, ... }:
{
  imports = [ ../core/<name>.nix ];

  config = lib.mkIf config.custom.hm<Name>.enable {
    # Darwin-only additions — pick whichever HM upstream supports:
    #
    # (a) The HM `programs.<x>` module accepts `package = null` (writes config
    #     without installing a binary):
    programs.<x>.package = null;  # Cask provides the binary
    #
    # (b) The HM `programs.<x>` module rejects `package = null` (e.g. it reads
    #     `cfg.package.pname` to derive other options — vscode's HM module):
    #     bypass `programs.<x>` entirely and write config files via `home.file`,
    #     reusing a shared settings option declared in core.
    #
    #     home.file."Library/Application Support/<App>/settings.json".text =
    #       builtins.toJSON config.custom.hm<Name>.settings;
  };
}
```

### Cask + module coexistence (darwin)

When the binary comes from a Homebrew cask, the darwin wrapper still needs to land config files in the cask app's expected location (`~/Library/Application Support/<App>/...`) without installing a second copy from nixpkgs. There are **two patterns**, depending on what the upstream HM module allows:

1. **`programs.<x>.package = null`** — use when the upstream `programs.<x>` module accepts a null package (it then writes config but skips binary install). This is the lightest pattern: keep using `programs.<x>` for everything else (settings, extensions, profiles).

2. **Bypass `programs.<x>` and write via `home.file`** — use when the upstream module rejects `package = null` (e.g., it dereferences `cfg.package.pname` for other options). Define a shared settings attrset in `core/<name>.nix` as a module option (`custom.hm<Name>.settings`, type `attrsOf anything`); the linux wrapper feeds it to `programs.<x>.<settings option>`, the darwin wrapper writes `home.file."Library/Application Support/<App>/settings.json".text = builtins.toJSON cfg.settings;`. Hosts can extend or override settings per-key via normal module-system merging. Canonical exemplar: VS Code (HM's `programs.vscode` module rejects `package = null` — non-nullable `mkPackageOption` plus several `cfg.package.*` dereferences — so the darwin wrapper uses `home.file`).

Both patterns satisfy the "never both nixpkgs + cask for the same app" rule — neither installs a nixpkgs binary on darwin.

Whichever pattern you choose, **prefer Option 3 (app façade) over manual cask wiring**: a façade collapses cask + HM enable into one toggle and removes the foot-gun where enabling HM config without the cask leaves orphaned settings. Only fall back to manual coordination (cask in `homebrew.nix` + HM enable in `home-manager/default.nix`) for one-off cases where a façade is overkill — in that case, add cross-referencing inline comments on both sides.

### Option 3 — App façade (cross-layer)

When an Option 2 darwin variant needs a Homebrew cask for the binary, the cask declaration lives in **system scope** while the matching HM config lives in **user scope**. A home-manager module cannot set `homebrew.casks`, so a single HM toggle cannot bundle both pieces. The app façade pattern bridges the two layers under one host-facing toggle.

**Canonical exemplar:** VS Code — [modules/apps/darwin/vscode.nix](../../modules/apps/darwin/vscode.nix), [modules/apps/linux/vscode.nix](../../modules/apps/linux/vscode.nix). Built on top of the Option 2 trio in `modules/home-manager/{core,linux,darwin}/vscode.nix`.

#### Layout

```
modules/
  apps/
    darwin/<name>.nix    # cask + HM injection + flip custom.hm<Name>
    linux/<name>.nix     # HM injection + flip custom.hm<Name>
  home-manager/
    core/<name>.nix      # internal once an app façade exists
    linux/<name>.nix     # internal
    darwin/<name>.nix    # internal
```

#### `modules/apps/darwin/<name>.nix`

```nix
# modules/apps/darwin/<name>.nix
# Darwin app façade for <name>: owns the Homebrew cask AND wires the matching
# home-manager config under one toggle.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/<name>.nix ];
#   custom.app<Name>.enable = true;

{ config, lib, userSettings, ... }:

let
  cfg = config.custom.app<Name>;
in
{
  options.custom.app<Name>.enable = lib.mkEnableOption "<description> (cask + HM config)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "<cask-name>" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/<name>.nix ];
      custom.hm<Name>.enable = true;
    };
  };
}
```

#### `modules/apps/linux/<name>.nix`

```nix
# modules/apps/linux/<name>.nix
# Linux app façade for <name>: thin forwarder that pulls the matching home-manager
# config under the same `custom.app<Name>.enable` toggle used on darwin.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/<name>.nix ];
#   custom.app<Name>.enable = true;

{ config, lib, userSettings, ... }:

let
  cfg = config.custom.app<Name>;
in
{
  options.custom.app<Name>.enable = lib.mkEnableOption "<description> (nixpkgs binary + HM config)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/<name>.nix ];
      custom.hm<Name>.enable = true;
    };
  };
}
```

#### Host wiring

Identical on every host:

```nix
# hosts/<HOST>/configuration/default.nix
imports = [ ../../../modules/apps/<os>/<name>.nix ];   # <os> = darwin or linux
custom.app<Name>.enable = true;
```

#### Rules

- The façade declares the option in **system scope**. `userSettings` is available via `specialArgs` (see `flake/darwin.nix` / `flake/nixos.nix`).
- Same option name across all OSes — `custom.app<Name>.enable` reads identically on JIN, FENNEC, EDGE.
- Once an `app<Name>` façade exists, hosts must NOT set the underlying `custom.hm<Name>.enable` directly. The HM trio becomes internal; the façade is the single entry point.
- The Linux façade is often a thin forwarder — accepted as the price of OS-symmetric wiring.
- Add an `app<Name>` façade only when binary and config cross layer boundaries (cask + HM-config). Pure-HM apps stay `hm*`; pure-system apps stay `sys*`.

### Single option, many wrappers

Even with three files, there is **one** option: `custom.hm<Name>.enable`. Defined in `core/`, exported transparently through both wrappers because they import core. Never split into per-OS variants like `custom.hm<Name>Linux.enable`.

### Do / Don't checklist

✅ **Do:**

- Default to Option 1; escalate to Option 2 only when forced.
- Refactor `all/<name>.nix` → `core/<name>.nix` + wrappers when the file accumulates `pkgs.stdenv.isDarwin` branches > ~5 lines or when you need a cask-backed darwin variant.
- Place wrapper files in `linux/` and `darwin/` even when their bodies are nearly empty — they are the host-facing entry point.
- Update [HOME-MANAGER.md](../../HOME-MANAGER.md) when adding new modules; list `core/` modules in their own section.
- Use `lib.mkForce` in a wrapper when overriding a value the core sets (e.g., `programs.vscode.profiles.default.extensions = lib.mkForce [ ];` on darwin).
- For cask-backed darwin Option 2 modules, prefer adding an Option 3 façade so hosts wire one toggle in `configuration/default.nix` instead of manually keeping cask and HM enable in sync.

❌ **Don't:**

- Import `core/<name>.nix` from a host file. Ever. Only `linux/` and `darwin/` may import core.
- Create per-OS option variants (`custom.hm<Name>Linux.enable`, `custom.hm<Name>Darwin.enable`).
- Put nontrivial `pkgs.stdenv.isDarwin` branching in an `all/` module — that's the trigger to escalate to Option 2.
- Promote a Linux-only or darwin-only module into `all/` just to "be tidy" — placement reflects actual portability, not aspiration.
- Install a GUI app via nixpkgs on darwin when a Homebrew cask exists. Use `programs.<x>.package = null` (when supported) or a `home.file` write of a shared `cfg.settings` attrset (when not) — see "Cask + module coexistence".
- Set `custom.hm<Name>.enable` directly from a host when an `app<Name>` façade exists. Use the façade.

### Future candidates (not yet refactored)

These home-manager modules currently live in `all/` or `linux/` and are likely Option 2 candidates if/when their darwin counterparts are needed:

- `all/syncthing.nix` — daemon config could be Option 1; the menubar UI is a separate `syncthing-app` cask on darwin (already coexists cleanly).
- `all/thunderbird.nix` — currently Linux-only enable; darwin uses cask. Move config to `core/` if EDGE ever wants declarative profiles.
- `all/brave.nix` — KDE-specific tweaks gated; darwin uses cask. Move shared bookmarks/policies to `core/` if needed.
- `all/nextcloud.nix` — daemon vs cask split, similar to Syncthing.
- `linux/vesktop.nix` — Linux-only by current placement; Option 2 candidate if you ever want it on darwin.
