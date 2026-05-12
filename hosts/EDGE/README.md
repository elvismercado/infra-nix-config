# EDGE

macOS desktop — 2018 MacBook Pro 15", Intel Core i9

## Hardware

| Component | Model                          |
| --------- | ------------------------------ |
| Machine   | MacBook Pro 15-inch, 2018      |
| CPU       | 2.9 GHz 6-Core Intel Core i9   |
| GPU       | Radeon Pro Vega 20 4 GB        |
| iGPU      | Intel UHD Graphics 630 1536 MB |
| RAM       | 32 GB 2400 MHz DDR4            |
| Storage   | 1 TB NVMe SSD                  |

## Configuration overview

- **OS:** macOS (nix-darwin), x86_64-darwin, stable channel
- **Nix Daemon:** Managed by Determinate installer (`nix.enable = false`)
- **Shell:** Bash (with completions), Starship prompt (pastel-powerline)
- **Networking:** WakeOnLAN, hostname/computerName/localHostName/SMB
- **Environment:** `LANG=en_GB.UTF-8`, timeZone `Europe/Amsterdam`
- **System Preferences:** Control Center, Dock, Finder, Trackpad, Power, Security (all managed)
- **Fonts:** Nerd Fonts, Google Fonts
- **System Packages:** git, gh, nano
- **Garbage Collection:** Disabled — Determinate Nix manages its own GC
- **Dev Tools:** Git, fnm (Node), pyenv (Python), Android tools, Ansible
- **CLI:** Fastfetch, SSH, shell aliases
- **macOS:** Rectangle (window management)

## Installed applications

Homebrew formulae, casks, and Mac App Store apps are declared in
[configuration/homebrew.nix](configuration/homebrew.nix) — that file
is the source of truth, with the same category grouping this README
used to mirror. Check there for the live list.

## Useful commands

```bash
# Rebuild and switch
darwin-rebuild switch --flake .#EDGE

# Or use the shell alias from anywhere
switch
```

## Hardware diagnostics

```bash
# System info
system_profiler SPHardwareDataType

# Memory
system_profiler SPMemoryDataType

# Storage
system_profiler SPStorageDataType
```
