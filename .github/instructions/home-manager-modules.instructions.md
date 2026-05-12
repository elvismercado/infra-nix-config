---
applyTo: "modules/home-manager/**,hosts/*/home-manager/**,flake/darwin.nix,flake/home.nix"
description: "Home-manager module patterns and API conventions"
---

## Home-Manager Module API

### Deprecation Awareness

Home-manager stable has restructured many `programs.*` modules. Top-level convenience options often move to nested structures between releases. Before using any `programs.<name>.*` option, verify it is current — don't assume the NixOS wiki or older examples reflect the stable channel API. Check for deprecation warnings after `switch`.

### programs.ssh

Options like `addKeysToAgent`, `serverAliveInterval`, `controlMaster`, `controlPath`, `controlPersist`, `hashKnownHosts`, `serverAliveCountMax` are per-host options — place them in `programs.ssh.matchBlocks."*"` (not top-level `programs.ssh`).

Set `programs.ssh.enableDefaultConfig = false` to avoid deprecation warnings about implicit defaults.

### File Conflicts (backupFileExtension)

When home-manager manages dotfiles (e.g., `~/.ssh/config`), activation fails if the file already exists. Always set `home-manager.backupFileExtension` in the flake integration:

- `flake/darwin.nix`: `home-manager.backupFileExtension = "backup";`
- `flake/nixos.nix`: `home-manager.backupFileExtension = "backup";`

### home.homeDirectory / home.username

On nix-darwin, set these directly without `lib.mkDefault` — they are not auto-derived from system config the way they are on NixOS.

### programs.git

Use `programs.git.settings` (not the deprecated top-level options):

- `userName` → `settings.user.name`
- `userEmail` → `settings.user.email`
- `aliases` → `settings.alias`
- `extraConfig` → merge directly into `settings`

Delta is a separate program — use `programs.delta.enable`, `programs.delta.options`, and set `programs.delta.enableGitIntegration = true` explicitly (not `programs.git.delta`).

### Package Names

nixpkgs renames packages between releases (e.g., `strawberry-qt6` → `strawberry`). Some packages are bundled — e.g., `kwrite` is not a separate attribute, it ships inside `kate`. Before using a package name in `home.packages` or `excludePackages`, verify the attribute exists in the current nixpkgs channel. Check [search.nixos.org](https://search.nixos.org/packages) or use `nix eval nixpkgs#<name>` to confirm.

### Desktop Entries vs Desktop Icons (KDE)

`xdg.desktopEntries` creates files in `~/.local/share/applications/` — these appear in the **KDE app menu/launcher** only.

To also show icons on the **KDE desktop surface**, add `home.file."Desktop/<name>.desktop"` entries pointing to `~/Desktop/`. These are separate locations — both are needed if you want an app in the menu AND on the desktop. Use `text` + `executable = true` to avoid KDE's "untrusted file" dialog.

### plasma-manager Limitations

- **Launcher favorites**: plasma-manager cannot set kickoff/kickerdash favorites. KDE stores them in `kactivitymanagerd-statsrc` with a per-instance UUID that changes on each `nixos-rebuild switch`. Use `iconTasks.launchers` on the task manager dock instead.
- **Camera indicator**: `org.kde.plasma.cameraindicator` only detects apps using the XDG Camera Portal (PipeWire camera API). Standalone webcam apps (Kamoso, Webcamoid, Cheese) access `/dev/video*` directly and never trigger it. It only activates for browser WebRTC video calls.

### Bash Shell Hooks (profileExtra vs initExtra)

Linux terminal emulators (Konsole, GNOME Terminal) open interactive-only shells — `profileExtra` is skipped. Only `initExtra` and `bashrcExtra` run. Place startup commands (like fastfetch) in `initExtra`, not `profileExtra`. macOS Terminal.app and SSH sessions are login shells and run all hooks.

## Cross-Platform Modules: Option 1 vs Option 2

When a home-manager module needs to run on both Linux and macOS, use the simplest pattern that works. The full strategy lives in [.github/instructions/cross-platform.instructions.md](cross-platform.instructions.md); the short version:

### Option 1 — single `all/<name>.nix` (default)

Use when home-manager upstream (`programs.<x>`) is cross-platform AND there is no Homebrew-cask conflict on darwin. The module is identical for every host.

Canonical exemplar: [modules/home-manager/all/git.nix](../../modules/home-manager/all/git.nix).

```nix
# modules/home-manager/all/<name>.nix
{ config, lib, ... }:
{
  options.custom.hm<Name>.enable = lib.mkEnableOption "<description>";

  config = lib.mkIf config.custom.hm<Name>.enable {
    programs.<x>.enable = true;
  };
}
```

### Option 2 — `core/` + `linux/` + `darwin/` trio

Use when ANY of: the package differs per OS, runtime semantics diverge meaningfully, or `pkgs.stdenv.isDarwin` branches in an `all/` file would exceed ~5 lines. Canonical exemplar: VS Code (`core/vscode.nix` + `linux/vscode.nix` + `darwin/vscode.nix`).

> **If the darwin variant needs a Homebrew cask for the binary, escalate further to Option 3 (app façade) — see [cross-platform.instructions.md](cross-platform.instructions.md). The Option 2 trio stays in place but its `custom.hm<Name>.enable` becomes internal; hosts wire `custom.app<Name>.enable` from `configuration/default.nix` instead.**

**Rules:**

- The `core/` file defines the option (`custom.hm<Name>.enable`) and all shared config. **Hosts must NEVER import from `core/`.**
- `linux/<name>.nix` and `darwin/<name>.nix` import the core file and add only OS-specific config inside `lib.mkIf cfg.enable`.
- One option for the user, regardless of OS — never `custom.hm<Name>Linux.enable` / `custom.hm<Name>Darwin.enable`.
- `core/<name>.nix` header MUST contain: `Internal — do not import from hosts. Imported by linux/<name>.nix and darwin/<name>.nix.`

```nix
# modules/home-manager/core/<name>.nix
# Internal — do not import from hosts. Imported by linux/<name>.nix and darwin/<name>.nix.
{ config, lib, ... }:
{
  options.custom.hm<Name>.enable = lib.mkEnableOption "<description>";

  config = lib.mkIf config.custom.hm<Name>.enable {
    # All shared config here
  };
}
```

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
    # Linux-only additions (often empty)
  };
}
```

```nix
# modules/home-manager/darwin/<name>.nix
# Darwin wrapper for the cross-platform <name> core module.
#
# Usage:
#   imports = [ ../../../modules/home-manager/darwin/<name>.nix ];
#   custom.hm<Name>.enable = true;
{ config, lib, ... }:
{
  imports = [ ../core/<name>.nix ];

  config = lib.mkIf config.custom.hm<Name>.enable {
    # Darwin-only additions. Two common shapes:
    #   - `programs.<x>.package = null` when the upstream HM module accepts it.
    #   - `home.file."Library/Application Support/<App>/settings.json".text =
    #        builtins.toJSON config.custom.hm<Name>.settings;` when it doesn't
    #     (declare a `custom.hm<Name>.settings` option in core for the linux
    #     wrapper to consume too — see vscode for the canonical example).
  };
}
```

### Cask + module coexistence (darwin)

When a darwin wrapper combines a Homebrew cask (binary) with a home-manager module (declarative config), use one of two write mechanisms:

1. **`programs.<x>.package = null`** — if the upstream HM module accepts a null package. HM still writes config files but skips binary install.
2. **Bypass `programs.<x>` and write via `home.file`** — if the upstream module rejects `package = null` (e.g., it dereferences `cfg.package.pname`). Declare a shared settings attrset in `core/<name>.nix` as a typed option (`custom.hm<Name>.settings`, `attrsOf anything`); the linux wrapper feeds it to `programs.<x>.<settings option>`, the darwin wrapper writes it via `home.file` to the cask's expected settings path. Canonical exemplar: VS Code.

Neither pattern installs a nixpkgs binary on darwin, so neither violates the "no GUI apps via nixpkgs on macOS" rule. The cask is still the binary source.

**Preferred wiring:** wrap this combination in an Option 3 app façade (`modules/apps/darwin/<name>.nix`). The façade owns the cask declaration AND auto-imports the HM darwin wrapper under one toggle (`custom.app<Name>.enable`), so the cask and HM enable cannot drift out of sync. See [cross-platform.instructions.md](cross-platform.instructions.md) Option 3.

**Manual coexistence (legacy, discouraged):** if a façade is overkill for a one-off case, you may keep cask in `hosts/<HOST>/configuration/homebrew.nix` and the HM enable in `hosts/<HOST>/home-manager/default.nix` — but add cross-referencing inline comments on both sides so the coupling is discoverable. New cask-backed apps should use Option 3 instead of this manual approach.
