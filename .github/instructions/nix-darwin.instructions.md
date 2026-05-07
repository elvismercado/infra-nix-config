---
applyTo: "hosts/*/configuration/**,modules/systems/darwin/**,modules/apps/darwin/**,flake/darwin.nix"
description: "nix-darwin specific constraints and gotchas"
---

## nix-darwin Constraints

### Commands Under sudo

`darwin-rebuild switch` runs as root via `sudo`. Root's PATH does not include `/usr/bin`. Always use absolute paths for macOS system commands:

- `/usr/bin/defaults` (not `defaults`)
- `/usr/bin/open` (not `open`)
- `/usr/sbin/softwareupdate` (not `softwareupdate`)

### Required Options

- `system.primaryUser` — must be set when `homebrew.enable = true`
- `users.knownUsers` — must list usernames for nix-darwin to manage them
- `users.users.<name>.uid` — required on nix-darwin (NixOS auto-assigns)
- `environment.shells` — must include the user's shell package (e.g., `pkgs.bashInteractive`)

### Shell

Use `pkgs.bashInteractive` (not `pkgs.bash`) for user login shells on macOS. The non-interactive variant lacks readline support.

### Determinate Nix Hosts

When `nix.enable = false` (Determinate Nix manages the daemon):

- Do not set `nix.gc.automatic`, `nix.optimise.automatic`, or any `nix.settings`
- Disable any garbage collection modules (`custom.sysGc.enable = false`)

### Homebrew Cask Names

Homebrew renames casks periodically. Always verify current cask names at `formulae.brew.sh` before adding to `homebrew.casks`. Former tokens (e.g., `handbrake` → `handbrake-app`, `mullvadvpn` → `mullvad-vpn`, `protonmail-bridge` → `proton-mail-bridge`, `syncthing` → `syncthing-app`) become aliases that may break.

### universalaccess Domain (SIP/TCC Protected)

`system.defaults.universalaccess.*` options (reduceTransparency, reduceMotion, etc.) fail at activation with "Could not write domain com.apple.universalaccess". The domain is protected by macOS SIP/TCC. Do not use these options — set them manually in System Preferences > Accessibility instead. See nix-darwin#705.

### Overlapping system.defaults Domains

Multiple nix-darwin paths can write to the same macOS defaults domain:

- `system.defaults.finder.X` and `CustomUserPreferences."com.apple.finder".X` both write to `com.apple.finder`
- `system.defaults.NSGlobalDomain.X` overlaps with `CustomUserPreferences.NSGlobalDomain.X`
- Some Finder options (e.g., `AppleShowAllExtensions`) exist in both `system.defaults.finder` and `NSGlobalDomain`

Before adding a setting to `system-preferences.nix` or `CustomUserPreferences`, check whether it's already covered by a dedicated module (`finder.nix`, `dock.nix`, `trackpad.nix`). Prefer the dedicated module.

### macOS Application Firewall

Most nix-darwin dev setups skip `networking.applicationFirewall.enable`. The firewall causes repeated "allow incoming connections?" prompts for dev tools (Node, Docker, Python servers). Behind a home router/NAT (especially with a VPN like Mullvad), the marginal security benefit rarely justifies the annoyance. Do not enable unless the user explicitly requests it.
