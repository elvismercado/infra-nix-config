# Home Manager

Home Manager manages user-level configuration: dotfiles, shell settings, user
applications, and Nix packages.

This repository supports two Home Manager integration modes:

- NixOS and nix-darwin hosts apply Home Manager as part of the system rebuild.
- Other Linux distributions apply it standalone through a host registered in
  `homeManagerHosts` in `flake/hosts.nix`.

## Current Hosts

| Host   | System        | Channel | HM Integration |
| ------ | ------------- | ------- | -------------- |
| JIN    | x86_64-linux  | stable  | NixOS module   |
| FENNEC | x86_64-linux  | stable  | NixOS module   |
| LULA   | x86_64-linux  | stable  | NixOS module   |
| EDGE   | x86_64-darwin | stable  | darwin module  |

No standalone Linux hosts are registered yet.

## Apply

Home Manager config is applied as part of the system rebuild:

```bash
sudo nixos-rebuild switch --flake .#JIN
sudo nixos-rebuild switch --flake .#FENNEC
sudo nixos-rebuild switch --flake .#LULA
darwin-rebuild switch --flake .#EDGE
```

For a registered standalone Linux host:

```bash
home-manager switch --flake .#<HOST> \
  --option access-tokens "github.com=$(gh auth token)"
```

The access token is required because the flake reads per-host private settings
from `elvismercado/infra-nix-config-private`.

## How It Works

1. `flake/hosts.nix` defines three host sets: `nixosHosts`, `darwinHosts`, and `homeManagerHosts` (the last is for standalone Home Manager hosts and is currently empty).
2. `flake/nixos.nix` and `flake/darwin.nix` pull in `home-manager.nixosModules.home-manager` / `home-manager.darwinModules.home-manager`, applying each host's `home-manager/` directory as part of the system rebuild.
3. `flake/home.nix` iterates over `homeManagerHosts` and builds a `homeManagerConfiguration` for each — these are exposed as `homeConfigurations.<HOST>` for `home-manager switch`. Linux hosts automatically enable `targets.genericLinux` for non-NixOS XDG, profile, and session integration.
4. The nixpkgs channel and system architecture are selected per-host from `user-settings.nix` via `selectNixpkgs`. The Home Manager version is selected per-host via `selectHomeManager` — a `"stable"` host uses `home-manager-stable`, an `"unstable"` host uses `home-manager`.

### What gets passed to modules

Every Home Manager module receives these via `extraSpecialArgs`:

- `inputs` — all flake inputs
- `userSettings` — the host's `user-settings.nix` (`username`, `hostname`, `system`, `channel`, `uid`, `repoPath`, and optionally `timeZone` and `desktopEnvironment`)
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

| Module                           | Option                                                                                                                                                                                                                                                                                                                                   |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `home-manager/all/base.nix`      | `custom.hmBase.enable`                                                                                                                                                                                                                                                                                                                   |
|                                  | `custom.hmBase.editor`                                                                                                                                                                                                                                                                                                                   |
| `home-manager/all/aliases.nix`   | `custom.hmAliases.enable`                                                                                                                                                                                                                                                                                                                |
| `home-manager/all/android.nix`   | `custom.hmAndroid.enable`                                                                                                                                                                                                                                                                                                                |
| `home-manager/all/ansible.nix`   | `custom.hmAnsible.enable`                                                                                                                                                                                                                                                                                                                |
| `home-manager/all/bash.nix`      | `custom.hmBash.enable`                                                                                                                                                                                                                                                                                                                   |
| `home-manager/all/fastfetch.nix` | `custom.hmFastfetch.enable`                                                                                                                                                                                                                                                                                                              |
| `home-manager/all/fnm.nix`       | `custom.hmFnm.enable`                                                                                                                                                                                                                                                                                                                    |
| `home-manager/all/git.nix`       | `custom.hmGit.enable`                                                                                                                                                                                                                                                                                                                    |
| `home-manager/all/pyenv.nix`     | `custom.hmPyenv.enable`                                                                                                                                                                                                                                                                                                                  |
| `home-manager/all/ssh.nix`       | `custom.hmSsh.enable`                                                                                                                                                                                                                                                                                                                    |
| `home-manager/all/starship.nix`  | `custom.hmStarship.enable`                                                                                                                                                                                                                                                                                                               |
|                                  | `custom.hmStarship.style`                                                                                                                                                                                                                                                                                                                |
| `home-manager/all/syncthing.nix` | `custom.hmSyncthing.enable` (+ `.defaultFolderPath` str default `~/cloud/syncthing`, `.ignorePermsByDefault` bool default `true`, `.defaultIgnoreLines` list — unified Linux + macOS module backed by `services.syncthing`; auto-imported by `modules/apps/{linux,darwin}/syncthing.nix` — prefer enabling `custom.appSyncthing.enable`) |

**Cross-platform core (internal — do not import from hosts)** (`home-manager/core/`):

These files hold shared logic for split (Option 2) modules. Hosts import the matching `linux/` or `darwin/` wrapper instead, **or** — when a cross-layer app façade exists — enable the façade and let it pull the wrapper in. See [.github/instructions/cross-platform.instructions.md](.github/instructions/cross-platform.instructions.md).

| Module                                | Option                                                               | Wrappers                                              | App façade (preferred wiring)                    |
| ------------------------------------- | -------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------ |
| `home-manager/core/brave.nix`         | `custom.hmBrave.enable`                                              | `linux/brave.nix`, `darwin/brave.nix`                 | `custom.appBrave.enable` (`modules/apps/`)       |
| `home-manager/core/discord.nix`       | `custom.hmDiscord.enable`                                            | `linux/discord.nix`, `darwin/discord.nix`             | `custom.appDiscord.enable` (`modules/apps/`)     |
| `home-manager/core/handbrake.nix`     | `custom.hmHandbrake.enable`                                          | `linux/handbrake.nix`, `darwin/handbrake.nix`         | `custom.appHandbrake.enable` (`modules/apps/`)   |
| `home-manager/core/librewolf.nix`     | `custom.hmLibrewolf.enable`                                          | `linux/librewolf.nix`, `darwin/librewolf.nix`         | `custom.appLibrewolf.enable` (`modules/apps/`)   |
|                                       | `custom.hmLibrewolf.settings`                                        |                                                       |                                                  |
| `home-manager/core/mpv.nix`           | `custom.hmMpv.enable`                                                | `linux/mpv.nix`, `darwin/mpv.nix`                     | `custom.appMpv.enable` (`modules/apps/`)         |
| `home-manager/core/nextcloud.nix`     | `custom.hmNextcloud.enable`                                          | `linux/nextcloud.nix`, `darwin/nextcloud.nix`         | `custom.appNextcloud.enable` (`modules/apps/`)   |
| `home-manager/core/thunderbird.nix`   | `custom.hmThunderbird.enable`                                        | `linux/thunderbird.nix`, `darwin/thunderbird.nix`     | `custom.appThunderbird.enable` (`modules/apps/`) |
| `home-manager/core/vscode.nix`        | `custom.hmVscode.enable`                                             | `linux/vscode.nix`, `darwin/vscode.nix`               | `custom.appVscode.enable` (`modules/apps/`)      |
| `home-manager/core/web-shortcuts.nix` | `custom.hmWebShortcuts.enable` <br/> `custom.hmWebShortcuts.entries` | `linux/web-shortcuts.nix`, `darwin/web-shortcuts.nix` | — (helper consumed by app modules)               |

**Linux — KDE Plasma** (`home-manager/linux/`):

| Module                                            | Option                                                                                                                                                                                                                                                                                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `home-manager/linux/aliases.nix`                  | `custom.hmLinuxAliases.enable`                                                                                                                                                                                                                                                                                                  |
|                                                   | `custom.hmAliasesAmdCpu.enable`                                                                                                                                                                                                                                                                                                 |
|                                                   | `custom.hmAliasesNvidiaGpu.enable`                                                                                                                                                                                                                                                                                              |
| `home-manager/linux/autostart.nix`                | `custom.hmAutostart.enable`                                                                                                                                                                                                                                                                                                     |
|                                                   | `custom.hmAutostart.entries`                                                                                                                                                                                                                                                                                                    |
| `home-manager/linux/webcamoid.nix`                | `custom.hmWebcamoid.enable`                                                                                                                                                                                                                                                                                                     |
| `home-manager/linux/clonehero.nix`                | `custom.hmCloneHero.enable`                                                                                                                                                                                                                                                                                                     |
|                                                   | `custom.hmCloneHero.version`                                                                                                                                                                                                                                                                                                    |
|                                                   | `custom.hmCloneHero.hash`                                                                                                                                                                                                                                                                                                       |
| `home-manager/linux/display-profiles.nix`         | `custom.hmDisplayProfiles.enable`                                                                                                                                                                                                                                                                                               |
| `home-manager/linux/gaming.nix`                   | `custom.hmGaming.enable`                                                                                                                                                                                                                                                                                                        |
| `home-manager/linux/handbrake.nix`                | `custom.hmHandbrake.enable` (wrapper for `core/handbrake.nix`; auto-imported by `modules/apps/linux/handbrake.nix` — prefer enabling `custom.appHandbrake.enable`)                                                                                                                                                              |
| `home-manager/linux/kwin-tiling.nix`              | `custom.hmKwinTiling.enable`                                                                                                                                                                                                                                                                                                    |
|                                                   | `custom.hmKwinTiling.layouts`                                                                                                                                                                                                                                                                                                   |
| `home-manager/linux/linutil.nix`                  | `custom.hmLinutil.enable`                                                                                                                                                                                                                                                                                                       |
| `home-manager/linux/nixos-diagnostics.nix`        | `custom.hmNixosDiagnostics.enable`; installs the `nixos-diagnostics` CLI and a Desktop launcher that publishes redacted support reports under `~/Desktop/NixOS Diagnostics` (review before sharing)                                                                                                                             |
|                                                   | `custom.hmNixosDiagnostics.retention` (positive integer, default: `5`)                                                                                                                                                                                                                                                          |
| `home-manager/linux/mpv.nix`                      | `custom.hmMpv.enable` (wrapper for `core/mpv.nix`; auto-imported by `modules/apps/linux/mpv.nix` — prefer enabling `custom.appMpv.enable`)                                                                                                                                                                                      |
| `home-manager/linux/nextcloud.nix`                | `custom.hmNextcloud.enable` (wrapper for `core/nextcloud.nix`; auto-imported by `modules/apps/linux/nextcloud.nix` — prefer enabling `custom.appNextcloud.enable`)                                                                                                                                                              |
| `home-manager/linux/vscode.nix`                   | `custom.hmVscode.enable` (wrapper for `core/vscode.nix`; auto-imported by `modules/apps/linux/vscode.nix` — prefer enabling `custom.appVscode.enable`)                                                                                                                                                                          |
| `home-manager/linux/plasma/common.nix`            | `custom.hmPlasmaCommon.enable` (internal - flipped by layout modules; sub-options `.systray.weather.enable`, `.hotCorners.enable`, `.kwallet.enable`, `.singleClickToOpen`, `.cursor.enable`, `.confirmLogout.enable`, `.dolphin.enable`, `.dolphin.showToolTips`, `.quickTile.shortcuts.enable`, `.quickTile.edgeDrag.enable`) |
| `home-manager/linux/plasma/macos.nix`             | `custom.hmPlasmaMacos.enable` (macOS-style two-panel layout: top menu bar with Global Menu + floating bottom dock; used by JIN, FENNEC)                                                                                                                                                                                         |
| `home-manager/linux/plasma/lula.nix`              | `custom.hmPlasmaLula.enable` (parent-friendly layout: top tray panel + bottom dock, no Global Menu; used by LULA)                                                                                                                                                                                                               |
| `home-manager/linux/sddm-monitor-layout.nix`      | `custom.hmSddmMonitorLayout.enable`                                                                                                                                                                                                                                                                                             |
| `home-manager/linux/shutdown-disable-outputs.nix` | `custom.hmShutdownDisableOutputs.enable`                                                                                                                                                                                                                                                                                        |
| `home-manager/linux/strawberry.nix`               | `custom.hmStrawberry.enable`                                                                                                                                                                                                                                                                                                    |
| `home-manager/linux/trayscale.nix`                | `custom.hmTrayscale.enable` (GTK system-tray front-end for the Tailscale CLI client; pairs with `custom.sysNixTailscale.enable`)                                                                                                                                                                                                |
| `home-manager/linux/web-shortcuts.nix`            | `custom.hmWebShortcuts.enable` (wrapper for `core/web-shortcuts.nix`; renders `~/Desktop/<key>.desktop` launchers — typically flipped by app wrappers)                                                                                                                                                                          |
| `home-manager/linux/discord.nix`                  | `custom.hmDiscord.enable` (wrapper for `core/discord.nix`; auto-imported by `modules/apps/linux/discord.nix` — prefer enabling `custom.appDiscord.enable`)                                                                                                                                                                      |
| `home-manager/linux/window-shortcuts.nix`         | `custom.hmWindowShortcuts.enable`                                                                                                                                                                                                                                                                                               |

**macOS** (`home-manager/darwin/`):

| Module                                      | Option                                                                                                                                                                                                                                                                                                       |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `home-manager/darwin/aliases.nix`           | `custom.hmDarwinAliases.enable`                                                                                                                                                                                                                                                                              |
| `home-manager/darwin/macos-diagnostics.nix` | `custom.hmMacosDiagnostics.enable`; installs the `macos-diagnostics` CLI and a Finder-launchable `Run Diagnostics.command`, bounds collected sections to 5 MiB, then atomically publishes redacted support reports under `~/Desktop/macOS Diagnostics` only after redaction succeeds (review before sharing) |
|                                             | `custom.hmMacosDiagnostics.retention` (positive integer, default: `5`)                                                                                                                                                                                                                                       |
| `home-manager/darwin/mpv.nix`               | `custom.hmMpv.enable` (wrapper for `core/mpv.nix`; auto-imported by `modules/apps/darwin/mpv.nix` — prefer enabling `custom.appMpv.enable`)                                                                                                                                                                  |
| `home-manager/darwin/rectangle.nix`         | `custom.hmRectangle.enable`                                                                                                                                                                                                                                                                                  |
| `home-manager/darwin/vscode.nix`            | `custom.hmVscode.enable` (wrapper for `core/vscode.nix`; auto-imported by `modules/apps/darwin/vscode.nix` — prefer enabling `custom.appVscode.enable`)                                                                                                                                                      |
| `home-manager/darwin/web-shortcuts.nix`     | `custom.hmWebShortcuts.enable` (wrapper for `core/web-shortcuts.nix`; renders `~/Desktop/<key>.webloc` launchers — typically flipped by app wrappers)                                                                                                                                                        |

> `systems/shared/ssh-server.nix` (`custom.sysSshServer.enable`) is a **system** module — use it in `configuration/default.nix`, not in `home-manager/default.nix`.

### Cross-Layer App Façades

Apps whose binary lives in a different layer than their config (typically a Homebrew cask on darwin + declarative HM settings) are wired through façade modules under `modules/apps/{darwin,linux}/`. The façade is a **system module** — import it from `hosts/<HOST>/configuration/default.nix`, NOT from `home-manager/default.nix`. The same toggle name is used on every OS, and the façade auto-pulls the matching home-manager wrapper into HM scope.

| Façade                                         | Option                                 | Owns                                                                                                                                                |
| ---------------------------------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modules/apps/darwin/beeper.nix`               | `custom.appBeeper.enable`              | `homebrew.casks += [ "beeper" ]`                                                                                                                    |
| `modules/apps/linux/beeper.nix`                | `custom.appBeeper.enable`              | `home.packages += [ pkgs.beeper ]` (unfree)                                                                                                         |
| `modules/apps/darwin/brave.nix`                | `custom.appBrave.enable`               | `homebrew.casks += [ "brave-browser" ]` + HM darwin wrapper auto-import + managed policies (`custom.sysBravePolicies`)                              |
| `modules/apps/linux/brave.nix`                 | `custom.appBrave.enable`               | HM linux wrapper auto-import (Plasma integration when `desktopEnvironment = "kde-plasma"`) + managed policies (`custom.sysBravePolicies`)           |
| `modules/apps/darwin/discord.nix`              | `custom.appDiscord.enable`             | `homebrew.casks += [ "vesktop" ]` + HM darwin wrapper auto-import (vesktop preferred over upstream `discord` cask)                                  |
| `modules/apps/linux/discord.nix`               | `custom.appDiscord.enable`             | HM linux wrapper auto-import (`pkgs.vesktop`)                                                                                                       |
| `modules/apps/darwin/ferdium.nix`              | `custom.appFerdium.enable`             | `homebrew.casks += [ "ferdium" ]`                                                                                                                   |
| `modules/apps/linux/ferdium.nix`               | `custom.appFerdium.enable`             | `home.packages += [ pkgs.ferdium ]`                                                                                                                 |
| `modules/apps/darwin/handbrake.nix`            | `custom.appHandbrake.enable`           | `homebrew.casks += [ "handbrake-app" ]` + HM darwin wrapper auto-import                                                                             |
| `modules/apps/linux/handbrake.nix`             | `custom.appHandbrake.enable`           | HM linux wrapper auto-import (`pkgs.handbrake`)                                                                                                     |
| `modules/apps/darwin/insync.nix`               | `custom.appInsync.enable`              | `homebrew.casks += [ "insync" ]`                                                                                                                    |
| `modules/apps/linux/insync.nix`                | `custom.appInsync.enable`              | `home.packages += [ pkgs.insync ]` (unfree)                                                                                                         |
| `modules/apps/darwin/libreoffice.nix`          | `custom.appLibreoffice.enable`         | `homebrew.casks += [ "libreoffice" ]`                                                                                                               |
| `modules/apps/linux/libreoffice.nix`           | `custom.appLibreoffice.enable`         | `home.packages += [ pkgs.libreoffice ]`                                                                                                             |
| `modules/apps/darwin/librewolf.nix`            | `custom.appLibrewolf.enable`           | `homebrew.casks += [ "librewolf" ]` + HM darwin wrapper auto-import (cask deprecated Sep 2026 — revisit)                                            |
| `modules/apps/linux/librewolf.nix`             | `custom.appLibrewolf.enable`           | HM linux wrapper auto-import                                                                                                                        |
| `modules/apps/darwin/localsend.nix`            | `custom.appLocalsend.enable`           | `homebrew.casks += [ "localsend" ]`                                                                                                                 |
| `modules/apps/linux/localsend.nix`             | `custom.appLocalsend.enable`           | `home.packages += [ pkgs.localsend ]`                                                                                                               |
| `modules/apps/darwin/moonlight.nix`            | `custom.appMoonlight.enable`           | `homebrew.casks += [ "moonlight" ]`                                                                                                                 |
| `modules/apps/linux/moonlight.nix`             | `custom.appMoonlight.enable`           | `home.packages += [ pkgs.moonlight-qt ]`                                                                                                            |
| `modules/apps/darwin/mpv.nix`                  | `custom.appMpv.enable`                 | `homebrew.brews += [ "mpv" ]` (ships `mpv.app` into `/Applications`; no working cask — `stolendata-mpv` deprecated) + HM darwin wrapper auto-import |
| `modules/apps/linux/mpv.nix`                   | `custom.appMpv.enable`                 | HM linux wrapper auto-import (`programs.mpv` → `pkgs.mpv` + `.desktop`)                                                                             |
| `modules/apps/darwin/mullvad-vpn.nix`          | `custom.appMullvadVpn.enable`          | `homebrew.casks += [ "mullvad-vpn" ]`                                                                                                               |
| `modules/apps/darwin/onlyoffice.nix`           | `custom.appOnlyoffice.enable`          | `homebrew.casks += [ "onlyoffice" ]`                                                                                                                |
| `modules/apps/linux/onlyoffice.nix`            | `custom.appOnlyoffice.enable`          | `home.packages += [ pkgs.onlyoffice-desktopeditors ]`                                                                                               |
| `modules/apps/linux/mullvad-vpn.nix`           | `custom.appMullvadVpn.enable`          | `services.mullvad-vpn` + `firewall.checkReversePath = "loose"` (WireGuard kill-switch) + `home.packages += [ pkgs.mullvad-vpn ]`                    |
| `modules/apps/darwin/nextcloud.nix`            | `custom.appNextcloud.enable`           | `homebrew.casks += [ "nextcloud" ]` + HM darwin wrapper auto-import                                                                                 |
| `modules/apps/linux/nextcloud.nix`             | `custom.appNextcloud.enable`           | HM linux wrapper auto-import (`services.nextcloud-client`)                                                                                          |
| `modules/apps/darwin/openlogi.nix`             | `custom.appOpenLogi.enable`            | `homebrew.casks += [ "openlogi" ]`                                                                                                                  |
| `modules/apps/linux/openlogi.nix`              | `custom.appOpenLogi.enable`            | Upstream NixOS module (`programs.openlogi` package + udev rules + graphical-session user service)                                                   |
| `modules/apps/darwin/proton-mail-bridge.nix`   | `custom.appProtonmailBridge.enable`    | `homebrew.casks += [ "proton-mail-bridge" ]`                                                                                                        |
| `modules/apps/linux/proton-mail-bridge.nix`    | `custom.appProtonmailBridge.enable`    | `home.packages += [ pkgs.protonmail-bridge-gui ]`                                                                                                   |
| `modules/apps/darwin/rpi-imager.nix`           | `custom.appRpiImager.enable`           | `homebrew.casks += [ "raspberry-pi-imager" ]`                                                                                                       |
| `modules/apps/linux/rpi-imager.nix`            | `custom.appRpiImager.enable`           | `home.packages += [ pkgs.rpi-imager ]`                                                                                                              |
| `modules/apps/darwin/rustdesk.nix`             | `custom.appRustdesk.enable`            | `homebrew.casks += [ "rustdesk" ]`                                                                                                                  |
| `modules/apps/linux/rustdesk.nix`              | `custom.appRustdesk.enable`            | `home.packages += [ pkgs.rustdesk-flutter ]` (interim — `pkgs.rustdesk` 1.4.6 build break, nixpkgs#527155)                                          |
| `modules/apps/darwin/shotcut.nix`              | `custom.appShotcut.enable`             | `homebrew.casks += [ "shotcut" ]`                                                                                                                   |
| `modules/apps/linux/shotcut.nix`               | `custom.appShotcut.enable`             | `home.packages += [ pkgs.shotcut ]`                                                                                                                 |
| `modules/apps/darwin/signal-desktop.nix`       | `custom.appSignal.enable`              | `homebrew.casks += [ "signal" ]`                                                                                                                    |
| `modules/apps/linux/signal-desktop.nix`        | `custom.appSignal.enable`              | `home.packages += [ pkgs.signal-desktop ]`                                                                                                          |
| `modules/apps/darwin/spotify.nix`              | `custom.appSpotify.enable`             | `homebrew.casks += [ "spotify" ]`                                                                                                                   |
| `modules/apps/linux/spotify.nix`               | `custom.appSpotify.enable`             | `home.packages += [ pkgs.spotify ]`                                                                                                                 |
| `modules/apps/darwin/steam.nix`                | `custom.appSteam.enable`               | `homebrew.casks += [ "steam" ]`                                                                                                                     |
| `modules/apps/linux/steam.nix`                 | `custom.appSteam.enable`               | `programs.steam` + GE-Proton + GameMode + Gamescope + Lutris + dualsensectl + 32-bit graphics + udev controller rules                               |
| `modules/apps/darwin/sweet-home3d.nix`         | `custom.appSweetHome3d.enable`         | `homebrew.casks += [ "sweet-home3d" ]`                                                                                                              |
| `modules/apps/linux/sweet-home3d.nix`          | `custom.appSweetHome3d.enable`         | `home.packages += [ pkgs.sweethome3d.application ]`                                                                                                 |
| `modules/apps/darwin/syncthing.nix`            | `custom.appSyncthing.enable`           | HM `all/syncthing.nix` auto-import (no cask — daemon is `pkgs.syncthing` via launchd)                                                               |
| `modules/apps/linux/syncthing.nix`             | `custom.appSyncthing.enable`           | HM `all/syncthing.nix` auto-import (`services.syncthing` + KDE tray)                                                                                |
| `modules/apps/darwin/thunderbird.nix`          | `custom.appThunderbird.enable`         | `homebrew.casks += [ "thunderbird" ]` + HM darwin wrapper auto-import (HM-side install-only: hunspell dicts; cask owns the binary)                  |
| `modules/apps/linux/thunderbird.nix`           | `custom.appThunderbird.enable`         | HM linux wrapper auto-import (`programs.thunderbird` + hunspell + dicts)                                                                            |
| `modules/apps/darwin/vscode.nix`               | `custom.appVscode.enable`              | `homebrew.casks += [ "visual-studio-code" ]` + HM darwin wrapper auto-import                                                                        |
| `modules/apps/linux/vscode.nix`                | `custom.appVscode.enable`              | HM linux wrapper auto-import (no system-layer binary needed)                                                                                        |
| `modules/apps/darwin/yubico-authenticator.nix` | `custom.appYubicoAuthenticator.enable` | `homebrew.casks += [ "yubico-authenticator" ]`                                                                                                      |
| `modules/apps/linux/yubico-authenticator.nix`  | `custom.appYubicoAuthenticator.enable` | `home.packages += [ pkgs.yubioath-flutter ]`                                                                                                        |

When an `app<Name>` façade exists, do NOT also set `custom.hm<Name>.enable` directly from a host — the façade handles it.

See [.github/instructions/cross-platform.instructions.md](.github/instructions/cross-platform.instructions.md) Option 3 for the full pattern.

## Adding a Standalone Linux Host

Use this path for Linux distributions that are not managed by NixOS, such as
Ubuntu, Debian, Fedora, or Arch Linux. The distribution continues to own the
kernel, bootloader, system services, and native packages. Nix and Home Manager
own this user's dotfiles and Nix packages.

### 1. Create the host settings

Create `hosts/<HOSTNAME>/user-settings.nix`:

```nix
{
  username = "myuser";
  hostname = "MYHOST";
  system = "x86_64-linux"; # or "aarch64-linux"
  channel = "stable"; # or "unstable"
  uid = 1000;
  repoPath = "git/infra-nix-config"; # relative to $HOME
  desktopEnvironment = null; # use "kde-plasma" when applicable
}
```

Private fields such as `timeZone`, `language`, and `regionalFormat` normally
live in `infra-nix-config-private/hosts/<HOSTNAME>/user-settings.nix`.

### 2. Create the Home Manager files

Create `hosts/<HOSTNAME>/home-manager/home.nix`:

```nix
{ userSettings, ... }:
{
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";
  home.stateVersion = "25.11";

  # Installs the CLI after the first activation.
  programs.home-manager.enable = true;
}
```

Set `home.stateVersion` to the Home Manager release used for the host's first
activation and do not change it during routine upgrades.

The standalone builder enables `targets.genericLinux` automatically for Linux
hosts. Do not repeat that option in each host configuration.

Create `hosts/<HOSTNAME>/home-manager/default.nix`:

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

Import Linux-specific modules only when they work without a NixOS system
module. In particular, `modules/home-manager/linux/aliases.nix` currently
defines NixOS rebuild commands and should not be enabled on standalone hosts.

### 3. Register the host

Add the host only to `homeManagerHosts` in `flake/hosts.nix`:

```nix
homeManagerHosts = {
  # `home-manager switch --flake .#MYHOST`
  MYHOST = mkHost "MYHOST";
};
```

A standalone host does not need `hosts/<HOSTNAME>/configuration/` and must not
also be added to `nixosHosts` or `darwinHosts`.

### 4. Bootstrap and apply

Install Nix with flakes enabled, install and authenticate GitHub CLI, then clone
the repository:

```bash
gh auth login
mkdir -p ~/git
git clone https://github.com/elvismercado/infra-nix-config ~/git/infra-nix-config
cd ~/git/infra-nix-config
```

Run Home Manager directly from its flake for the first activation:

```bash
nix run github:nix-community/home-manager -- \
  switch --flake .#MYHOST \
  --option access-tokens "github.com=$(gh auth token)"
```

After activation, `programs.home-manager.enable` provides the CLI. Future
updates use:

```bash
cd ~/git/infra-nix-config
git pull --ff-only
home-manager switch --flake .#MYHOST \
  --option access-tokens "github.com=$(gh auth token)"
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
