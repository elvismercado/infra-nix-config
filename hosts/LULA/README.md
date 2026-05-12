# LULA

macOS laptop — 2026 MacBook Neo, Apple A-series silicon. Personal
machine for a non-technical user, set up as a low-friction host.

## Hardware

| Component | Model                            |
| --------- | -------------------------------- |
| Machine   | MacBook Neo, 2026                |
| CPU       | Apple A-series silicon (aarch64) |
| GPU       | Integrated (Apple GPU)           |
| RAM       | (fill in after delivery)         |
| Storage   | (fill in after delivery)         |

## Configuration overview

- **OS:** macOS Tahoe (nix-darwin), aarch64-darwin, stable channel
- **Nix Daemon:** Managed by Determinate installer (`nix.enable = false`)
- **Shell:** Bash (with completions), Starship prompt (pastel-powerline)
- **Networking:** WakeOnLAN, hostname/computerName/localHostName/SMB
- **Environment:** `LANG=en_GB.UTF-8`, timeZone `Europe/Amsterdam`
- **System Preferences:** Control Center, System Preferences, Trackpad,
  Power, Security (all managed)
- **Fonts:** Nerd Fonts, Google Fonts
- **System Packages:** git, gh, nano
- **macOS auto-updates:** enabled (system + security + data files)
- **Garbage Collection:** Disabled — Determinate Nix manages its own GC
- **CLI:** Fastfetch, mpv, SSH, shell aliases — no dev tooling, no
  Rectangle, no Syncthing.

## Installed applications

LULA intentionally runs a minimal app set:

- **Brave** — primary browser. Managed policies (debrand + privacy) are
  applied, but **no force-installed extensions** (`custom.appBrave.extensions = []`).
  The user can install whatever they want from the Chrome Web Store.
- **LocalSend** — cross-device file sharing.
- **AppCleaner** (Homebrew cask) — clean uninstaller for the rare cases
  where the user installs something manually.

## Useful commands

```bash
# Rebuild and switch
sudo darwin-rebuild switch --flake .#LULA

# Or use the shell alias from anywhere
switch
```
