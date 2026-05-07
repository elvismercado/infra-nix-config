# Syncthing — pre-unification snapshot (2026-05-08)

Archived just before swapping the cask + per-OS wrapper trio for a single
unified `modules/home-manager/all/syncthing.nix` based on
`services.syncthing` (which has working `launchd.agents.syncthing` support
on darwin in upstream home-manager).

## What this snapshot contains

| Original path                               | Archived as                         |
| ------------------------------------------- | ----------------------------------- |
| `modules/apps/darwin/syncthing.nix`         | `apps/darwin/syncthing.nix`         |
| `modules/apps/linux/syncthing.nix`          | `apps/linux/syncthing.nix`          |
| `modules/home-manager/core/syncthing.nix`   | `home-manager/core/syncthing.nix`   |
| `modules/home-manager/linux/syncthing.nix`  | `home-manager/linux/syncthing.nix`  |
| `modules/home-manager/darwin/syncthing.nix` | `home-manager/darwin/syncthing.nix` |

The cask was `syncthing-app` (the menubar wrapper), wired with declarative
NSDefaults under `system.defaults.CustomUserPreferences."com.github.xor-gate.syncthing-macosx"`
to pin StartAtLogin / Sparkle telemetry / `--no-default-folder`.

## Why the snapshot

The unification removes the macOS menubar icon (no `services.syncthing`
tray equivalent on darwin — upstream HM has `assertPlatform = linux` on
`services.syncthing.tray`). If that turns out to be a regression worth
reverting (e.g. you miss the menubar quick-actions enough), this snapshot
is the rollback contract.

## Restore procedure

1. Copy each archived file back to its original path (table above).
2. Delete `modules/home-manager/all/syncthing.nix`.
3. Revert the `appSyncthing` row in `HOME-MANAGER.md`'s Cross-Layer App
   Façades table (re-add the cask reference) and the corresponding
   `home-manager/all/` table row.
4. `darwin-rebuild switch --flake .#EDGE` — nix-darwin will reinstall the
   cask. Existing `~/Library/Application Support/Syncthing/` state is
   preserved (same path under both setups; zero data loss).
5. `sudo nixos-rebuild switch --flake .#JIN` and `.#FENNEC` — no changes
   for them since their wrapper goes back to the same `services.syncthing`
   shape that the unified module also produced.

This folder is **not imported** by the flake. It is inert documentation +
rollback fodder. Safe to delete in a future cleanup commit once the
unified setup has proven stable.
