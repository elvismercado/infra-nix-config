# nix-config — Improvement Backlog

Open items only.

## Backlog — Pending Decisions

### Install experience — noise & deprecation surfaced during LULA install

- [x] **Silence `os-prober` errors during `nixos-install` on single-OS hosts.** ✅ Done 2026-05-19 — added `custom.sysNixGrub.useOSProber` (default `true`) to [modules/systems/nixos/bootloader/grub.nix](modules/systems/nixos/bootloader/grub.nix); set `false` on LULA and JIN (both single-OS). FENNEC keeps the default and continues to detect the Windows entry.
- [x] **Migrate `inputs.private` away from relative `git+file:` before Nix removes it.** ✅ Done 2026-05-19 — migrated to `github:elvismercado/nix-config-private` (private repo, tarball API). Auth is per-invocation via `--option access-tokens "github.com=$(gh auth token)"` spliced into every `switch*` alias in [modules/home-manager/{all,linux,darwin}/aliases.nix](modules/home-manager/all/aliases.nix); prerequisite is `gh auth login` once per user per host. `bumpPrivate` was dropped from `switch` / `switchcheck` since the fetch is now network-bound; `switchbumpprivate` remains the explicit "I edited the private overlay" command. On-disk sibling next to `nix-config` is no longer required for rebuilds (only for editing the overlay). See [flake.nix](flake.nix) header comment for the `path:` / `git+https:` / `git+ssh:` failure modes that ruled them out.
- [ ] **Investigate `download buffer is full` warning during `nixos-install`.** install.sh already passes `--option download-buffer-size 268435456` (256 MiB) but the warning still fires on LULA. Either the option doesn't apply early enough, or the substituter saturates faster than the configured buffer drains on the live ISO. Check whether bumping further (512 MiB / 1 GiB) helps, or whether this is a known cosmetic warning in current Nix.

### Display modules — parked, decide remove vs upgrade

- [ ] **`custom.sysNixPlymouth` + `custom.hmShutdownDisableOutputs` — improve before re-enabling (coupled).** Parked on JIN + FENNEC 2026-05-05. The shutdown-disable-outputs module exists _only_ to mitigate Plymouth's multi-monitor shutdown flicker, so the two are all-or-nothing: re-enable Plymouth (with fixes) → re-evaluate `hmShutdownDisableOutputs`; delete Plymouth permanently → also delete `hmShutdownDisableOutputs`. Issues to fix before re-enabling Plymouth:
  - `useSimpleDrm = false` workaround on JIN — amdgpu forced-SI ignores `video=<connector>:d`, so per-output suppression doesn't actually work. Need a real fix or remove the option.
  - `bootDisabledOutputs` mechanism is GPU-driver-dependent (works for some cards, ignored by amdgpu). Document supported drivers, or replace with a more reliable approach (e.g. early kscreen-doctor invocation).
  - Splash flickers/glitches at handoff to SDDM greeter — the new deterministic SDDM layout may help, but needs verification.
  - `minAnimationDuration = 3` is a hack to mask "boots faster than animation"; consider whether the splash adds value at all on a 5s NVMe boot.
  - Verify whether the multi-monitor shutdown flicker (the reason `hmShutdownDisableOutputs` exists) still occurs in current Plasma 6 / Plymouth. If fixed upstream, delete `hmShutdownDisableOutputs` and remove from HOME-MANAGER.md regardless of Plymouth outcome.
  - Re-enable plan: pick one host (FENNEC, simpler config), validate, then enable on JIN.

### Plasma — declarative widget config for systray-embedded widgets

- [ ] **Wire weather (and other systray-embedded widgets) declaratively.** Confirmed on LULA 2026-05-14: `~/.config/plasma-org.kde.plasma.desktop-appletsrc` shows `[Containments][41][Applets][44][Applets][52]` (the weather applet) with no `WeatherStation` group, despite [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix) trying to set `source` + `updateInterval` via `systemTray.items.configs`. Root cause: plasma-manager's `systemTray.items.configs` convert function silently drops per-widget configs for systray-embedded widgets — KDE's plasma scripting API can't reach into nested containments, and the relevant `extraConfig` block in upstream `modules/widgets/system-tray.nix` is commented out with the note _"Uncomment this if plasma scripting API ever adds support for nested containments"_. Same limitation hits any systray-embedded widget: `mediacontroller` (volume step), `devicenotifier` (removable-only filter), `clipboard` (history size), `keyboardlayout`, etc. Two viable fixes when we revisit:
  - **(a) Wait for upstream plasma-manager / KDE plasma scripting API.** Re-wire `systrayItems.configs` in `common.nix` once the upstream `extraConfig` block is enabled, and re-add the `weatherLocation.source` assertion.
  - **(b) Build a `home.activation` post-switch patcher.** ~15 lines of bash using `kwriteconfig6` that scans `plasma-org.kde.plasma.desktop-appletsrc` for `plugin=org.kde.plasma.<name>` lines, derives each containment path, and writes the relevant `[Configuration][<Group>]` keys. Idempotent; runs every `switch`. No-ops on a fresh install before the user has added the widget. Best modelled as a generic `custom.hmPlasmaSystrayConfigPatcher` consuming a freeform attrset like `{ "org.kde.plasma.weather".WeatherStation = { source = ...; updateInterval = ...; }; }`, so the same module covers all affected widgets.
  - **Workaround until then (current state):** the weather widget is pinned to the systray's `shown` list (works), but the user must right-click → Configure once to pick wttr.in + their location. Plasma persists across reboots. Affected hosts: JIN, FENNEC, LULA. Overlay schema (`source`, `latitude`, `longitude`, `updateIntervalMinutes`) is preserved as inert reference data so it's already in place when option (a) or (b) lands — see the KNOWN LIMITATION block in `common.nix` header.

### Future apps — parked until upstream packaging lands

- [ ] **Revert Linux RustDesk from `rustdesk-flutter` back to `pkgs.rustdesk` once it builds again.** `pkgs.rustdesk` 1.4.6 fails to build on Linux ([nixpkgs#527155](https://github.com/NixOS/nixpkgs/issues/527155): non-deterministic cargo-vendor FOD hash in `rustdesk-1.4.6-vendor-staging`, surfaces as a `rustdesk-org/wezterm` git-fetch failure). The fix is the version bump [PR #527831](https://github.com/NixOS/nixpkgs/pull/527831) (`1.4.6 → 1.4.7`), to be backported to 26.05. **Interim (2026-06-05):** [modules/apps/linux/rustdesk.nix](modules/apps/linux/rustdesk.nix) installs `pkgs.rustdesk-flutter` (1.4.5, a separate attribute that predates the break) and `custom.appRustdesk.enable = true;` is re-enabled on JIN, FENNEC, LULA. EDGE (Homebrew cask) is unaffected. Revert plan: `nix flake update`, confirm `nix build .#nixosConfigurations.JIN.config.system.build.toplevel` builds `pkgs.rustdesk`, then swap the package back to `pkgs.rustdesk` in the Linux façade (and update the HOME-MANAGER.md row).

- [ ] **Helium browser on LULA (alongside Brave).** Privacy-focused Chromium fork from imputnet ([helium.computer](https://helium.computer)). Not in nixpkgs as of May 2026; upstream is pre-1.0 and ships only `.deb` / `.tar.xz` / `.AppImage`. When it lands in nixpkgs (or stabilises at 1.0), add a `modules/apps/linux/helium.nix` cross-layer façade following the same pattern as [modules/apps/linux/brave.nix](modules/apps/linux/brave.nix) and enable on LULA via `custom.appHelium.enable = true;`. Brave stays primary on LULA — Helium is a secondary browser, no managed-policy module needed initially (Helium has no stable policy schema yet). Re-evaluate when: nixpkgs ships `helium-browser`, OR upstream tags 1.0.

### LULA — accessibility & usability tweaks (pick up one at a time)

Backlog of KDE Plasma + Dolphin + Brave tweaks aimed at non-tech-savvy / older users. Each item is independent; pick one, plan, implement, validate with the user, move on. Most land in [modules/home-manager/linux/plasma/{common,lula}.nix](modules/home-manager/linux/plasma/lula.nix) or [hosts/LULA/home-manager/default.nix](hosts/LULA/home-manager/default.nix). Where an option is genuinely cross-host useful (cursor size, confirm-on-logout, lock-panel), promote it to `common.nix` behind a `custom.hmPlasmaCommon.<name>` toggle; LULA-specific bits (Kickoff swap, dock icon size) stay in `lula.nix`.

**Top 5 to do first** (best UX-per-line-of-config):

1. ~~Cursor — 36px Breeze + Bouncing click feedback.~~ ✅ Done 2026-05-14 — `custom.hmPlasmaCommon.cursor.enable`.
2. ~~Confirm-on-logout.~~ ✅ Done 2026-05-14 — `custom.hmPlasmaCommon.confirmLogout.enable`.
3. Lock panel layout (prevent accidental drag-off). — see Safety nets entry; needs research before implementing.
4. ~~Klipper clipboard history limited to ~5 entries (privacy + clutter).~~ ✅ Done 2026-05-14 — `klipperrc [General] MaxClipItems=5`.
5. ~~Replace Application Dashboard with classic Kickoff.~~ ✅ Partial 2026-05-14 — Kickoff relocated to the bottom panel's left corner (flush-left, outside the centered iconTasks group); Kickerdash stays in the top-left. Trial: which launcher does she actually reach for? Kickoff also serves as the power menu since Kickerdash only exposes Leave/Restart/Shutdown.

#### High impact

- [x] **Single-window mode in Dolphin + sensible defaults.** ✅ Done 2026-05-19 — added `custom.hmPlasmaCommon.dolphin.enable` (default `false`) in [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix); enabled on LULA, FENNEC, JIN. Writes `dolphinrc [General]` keys `BrowseThroughArchives`, `ShowFullPath`, `ShowStatusBar`, `OpenExternallyCalledFolderInNewTab=false`, `RememberOpenedTabs=false`, plus `[KFileDialog Settings] View Style=DetailsView`. Hover file tooltips governed by separate `dolphin.showToolTips` sub-option (default `false`): off on LULA (KDE's hover-show delay is hardcoded too short for non-technical users and there is no declarative key to slow it down), on for FENNEC + JIN. Note: Dolphin's tabs feature itself has no declarative kill switch; `OpenExternallyCalledFolderInNewTab=false` is the closest approximation.
- [x] **Disable window-snapping / tiling shortcuts** ✅ Done 2026-05-19 — split into `custom.hmPlasmaCommon.quickTile.shortcuts.enable` and `custom.hmPlasmaCommon.quickTile.edgeDrag.enable` (both default `true`) in [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix). On LULA, `shortcuts.enable = false` unbinds the 8 Meta+arrow Quick Tile combos plus Meta+Up/Down (Maximize/Minimize); `edgeDrag.enable` left at default `true` so drag-to-edge snapping remains as a discoverable / learnable gesture.
- [ ] ~~**Window borders on maximized windows.**~~ **Skipped 2026-05-19** — verified on LULA that flipping `kwinrc [Windows] BorderlessMaximizedWindows` between `true` and `false` produces no visible change with current Plasma 6 + Breeze decorations (the global flag appears to be ignored by the current decoration plugin; per-window "no titlebar" via window rules still works, but the global setting does not). Maximized windows keep their titlebar + chrome regardless. Nothing to pin.

#### Visibility & legibility

- [x] **Global UI scaling 110–125%.** ✅ Done 2026-05-19 — declarative scaling is not viable on Plasma 6 Wayland (per-output scale lives in `~/.local/state/kwinoutputconfig.json`, keyed by EDID, written by KWin itself; plasma-manager [#243](https://github.com/nix-community/plasma-manager/issues/243) has no option for it and the X11-era `kdeglobals [KScreen] ScreenScaleFactors` is ignored by KWin Wayland for window placement). Resolved instead with a two-layer approach on LULA: (1) declarative `programs.plasma.fonts` set to Plasma 6 defaults +2pt across all six categories in [modules/home-manager/linux/plasma/lula.nix](modules/home-manager/linux/plasma/lula.nix); (2) optional stronger magnification via a one-time GUI step (System Settings → Display & Monitor → Global Scale) documented under "Display scaling" in [hosts/LULA/README.md](hosts/LULA/README.md). KWin persists the scale across reboots.
- [ ] ~~**High-contrast color scheme.**~~ **Skipped 2026-05-19** per user — keep the default Breeze colour scheme.
- [ ] **Always-visible scrollbars.** ⚠️ **Blocked: no declarative or GUI path in Plasma 6.** Breeze hardcodes transient/overlay scrollbar behaviour at the Qt style level — there is no kdeglobals/breezerc key, and the upstream `kcms/style/stylesettings.kcfg` exposes no scrollbar visibility option. Only available workarounds are `QT_STYLE_OVERRIDE=fusion` (replaces the entire widget style, visually inconsistent with the rest of Plasma) or per-app QSS overlays (not global). Park until upstream Breeze adds the setting, or revisit with the heavier `QT_STYLE_OVERRIDE` hammer if needed.
- [x] **Animated cursor when launching apps** (bouncy cursor while app starts). ✅ Done — already wired by `custom.hmPlasmaCommon.cursor.enable = true` on LULA, which sets `cursorFeedback = "Bouncing"` and `taskManagerFeedback = true` in [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix).

#### Notifications & focus

- [x] **Lengthen notification timeout** from 5s → 10s. ✅ Done 2026-05-19 — always-on baseline in [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix); writes `plasmanotifyrc [Notifications] PopupTimeout=10000` whenever `custom.hmPlasmaCommon.enable` is set. Applies to LULA, FENNEC, JIN.
- [x] **Pin click-to-focus explicitly.** ✅ Done 2026-05-19 — always-on baseline in [modules/home-manager/linux/plasma/common.nix](modules/home-manager/linux/plasma/common.nix); writes `kwinrc [Windows] FocusPolicy=ClickToFocus` (plasma-manager has no typed option for it, so set directly via `configFile`). Defensive against a future Plasma default flip.

#### Discoverability

- [ ] **Bigger dock icons + spacing.** Bump `panels[bottom].height` from 56 to 64–72 and set `iconTasks.iconSpacing = "large"`. Less precision required to click.
- [ ] **Show window labels in taskbar** — switch `iconTasks` → `org.kde.plasma.taskmanager` (icons + text). Two open Brave windows are indistinguishable by icon alone.
- [ ] **Disable "group by application"** in taskmanager — each window gets its own button. "Where's my email?" → one button per window, no hover-popup.
- [ ] **Replace Application Dashboard with Kickoff (or add Kickoff alongside).** Full-screen Dashboard hides the desktop and disorients. Classic Kickoff opens a small corner menu. Swap `org.kde.plasma.kickerdash` → `org.kde.plasma.kickoff` in [modules/home-manager/linux/plasma/lula.nix](modules/home-manager/linux/plasma/lula.nix) top panel.
- [ ] **Show Desktop button on bottom panel too.** One-click escape from clutter — already on top, mirror to bottom.

#### Safety nets

- [ ] **Lock panel layout** so she can't drag widgets off into oblivion. Two competing mechanisms, both with caveats — needs validation before committing:
  - **(a) `Containments[N].immutability=2`** in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`. Per-containment `immutability` value `2` (`SystemImmutable`) prevents edit-mode drags. Risk: plasma-manager's panel desktop-script _deletes and rebuilds_ `plasma-org.kde.plasma.desktop-appletsrc` on every switch (see `panelPreCMD` comment in upstream `modules/panels.nix`), so writes to that file from `programs.plasma.configFile` may be wiped. Likely needs a `home.activation` post-switch patcher that runs _after_ plasma-manager's script.
  - **(b) `kdeglobals [KDE Action Restrictions]` kiosk keys.** `action/plasma/add_widgets=false`, `action/plasma/configure=false`, `action/plasma/add_panel=false`, etc. Cleaner, written through plasma-manager's existing `configFile` mechanism, lives in a stable file. Downside: kiosk restrictions are coarser (no edit mode at all, including from System Settings).
  - **Decision pending.** Likely (b) wrapped in `custom.hmPlasmaCommon.lockPanels.enable` (default false), with the trade-off documented. Validate on LULA first; if it sticks, promote default to true on parent-style hosts.
- [ ] **Klipper clipboard history → 5 entries** (currently 20+ default). Old passwords / addresses leaking into history is a privacy + cognitive-load problem. `programs.plasma.configFile."klipperrc"` `[General] MaxClipItems=5; KeepClipboardContents=true;`.
- [ ] **Disable Plasma edit-mode shortcut** (Meta+D defaults). Accidental edit mode → accidental panel destruction.
- [ ] **Force "show hidden files = no" in Dolphin.** Forever. Discovering `.config` and "tidying it up" is a real failure mode.
- [ ] **Disable Shift+Delete** (bypass-trash). Trash-only, always.
- [ ] **KDE Connect off** unless she actually uses it — pairing prompts confuse. Currently not enabled — verify and pin.
- [ ] **Auto-lock screen after 15 min** (not 5). Long enough she doesn't keep seeing the login screen during normal use. `programs.plasma.kscreenlocker.timeout = 15;`.

#### Accessibility

- [ ] **Disable sticky-keys / slow-keys toggles** (5×Shift trigger). Accidental trigger = "my keyboard is broken" support call. Disable the gesture, keep the feature available via System Settings.
- [ ] **Shake mouse to find cursor** — wiggle the trackpad, cursor briefly enlarges. KWin effect: `programs.plasma.kwin.effects.shakeCursor.enable = true;` (verify exact path in plasma-manager).
- [ ] **Disable magnifier shortcut** (Meta+= → full-screen zoom). Surprise zoom is panic-inducing.
- [ ] **Document trackpad right-click gesture** (two-finger tap for right-click — libinput `clickfinger` is already default). README addition only, no config change.

#### Brave-side (lives in `modules/systems/shared/brave-policies-data.nix` or per-host extension)

- [ ] **Pin frequently-used bookmarks to the toolbar.** Gmail, news, Floccus settings, Bitwarden popup. Reduces "how do I get to my email" calls. Either via `ManagedBookmarks` policy (server-side managed, can't be deleted) or by seeding the `Bookmarks` JSON on first launch via `home.activation`. `ManagedBookmarks` is the right tool — already a policy mechanism, can't be accidentally deleted.

## Round 1 — flake/ folder & wiring

### P1 — Security & Correctness

- [ ] **Inconsistent public/private overlay merge depth — `hosts.nix` shallow vs `metadata.nix` recursive.** [flake/hosts.nix](flake/hosts.nix#L20) merges `userSettings = publicUserSettings // privateUserSettings;` (shallow `//`), while [flake/metadata.nix](flake/metadata.nix#L77) merges with `lib.recursiveUpdate (public.${name} or { }) (private.${name} or { })`. Both load the same kind of public-stub-plus-private-overlay split. Today `userSettings` is flat, so it works — but the moment someone adds a nested attr (e.g. `wireguard = { peer = ...; }`) under `userSettings`, the private side will silently obliterate the public side. Pick one merge strategy and use it for both loaders (recommend `lib.recursiveUpdate` everywhere).
- [ ] **`flake/metadata.nix` reads private repo via raw filesystem path, not via `inputs.private`.** [flake/metadata.nix](flake/metadata.nix#L67) uses `privateMetadata = ../../nix-config-private/metadata.nix;` — a path literal resolved against the live working tree at eval time, bypassing the locked `inputs.private` flake input that [flake/hosts.nix](flake/hosts.nix#L17) uses for the per-host overlay. Two consequences: (1) `metadata.nix` always sees uncommitted changes in the sibling repo while `hosts.nix` is locked at `nix flake update` time — divergent overlay semantics within one flake eval; (2) on hermetic evals (CI, restricted-eval) the path may not resolve. Switch to `inputs.private + "/metadata.nix"` to match `hosts.nix`'s pattern, or document the intentional asymmetry.

### P2 — Robustness & Reliability

- [ ] **`sddmMonitorLayout` activation snippet fails during `nixos-install` (TMPDIR missing).** [modules/systems/nixos/display_manager/sddm-monitor-layout.nix](modules/systems/nixos/display_manager/sddm-monitor-layout.nix#L88) calls `TMP=$(mktemp)` with no explicit dir. During `nixos-install` activation, `$TMPDIR` points at a parent temp dir under `/mnt/tmp.XXXXXXX/` that doesn't always exist, so `mktemp` fails with `No such file or directory` and the snippet errors out (`Activation script snippet 'sddmMonitorLayout' failed (1)`) plus the cascade `cp: cannot create regular file ''` / `jq: error: Could not open file` / `chown: cannot access '/var/lib/sddm/.config/kwinoutputconfig.json'`. First-boot `nixos-rebuild switch` succeeds because TMPDIR is normal. Fix: replace `TMP=$(mktemp)` with `TMP=$(mktemp -p "$SDDM_CONFIG")` — `$SDDM_CONFIG` was just `mkdir -p`'d, lives on the target fs, and avoids cross-fs rename concerns. Observed on JIN install 2026-05-13.
- [ ] **`mkHost` validates only `channel`; missing/invalid `system`/`username`/`uid`/`repoPath` surface as cryptic deep-stack errors.** [flake/hosts.nix](flake/hosts.nix#L22) throws a clear message when `channel` is bogus, but every other required field falls through to whoever consumes it (e.g. `nixosSystem { system = userSettings.system; }` → "value is null while a string was expected" 30 frames deep). Add an upfront `assert` block in `mkHost` listing required fields with a host-name-prefixed error.
- [ ] **No collision check across `nixosHosts`/`darwinHosts`/`homeManagerHosts` unions.** [flake/default.nix](flake/default.nix#L25) builds `allHosts = nixosHosts // darwinHosts // homeManagerHosts;` for the systems calculation. If a hostname accidentally appears in two registries, `//` silently overwrites and only one survives. Add an assertion that the sum of attrname counts equals the union's count.
- [ ] **`nixos.nix` reads `nixpkgs.lib.optional` from the unstable input regardless of host channel.** [flake/nixos.nix](flake/nixos.nix#L36) uses `nixpkgs.lib.optional (...)` inside the per-host module list while everything else for that host comes from `selectedNixpkgs`. `lib.optional` is channel-stable so no live bug, but it's a footgun: any future `nixpkgs.lib.<thing>` here silently bypasses the host's `selectNixpkgs`. Swap to `selectedNixpkgs.lib.optional`.

### P3 — Architecture & Convention

- [ ] **`flake/home.nix` machinery is wired up for a permanently empty registry — clarify intent.** [flake/hosts.nix](flake/hosts.nix#L60) defines `homeManagerHosts = { };` and [flake/default.nix](flake/default.nix#L48) still imports `flake/home.nix` and exposes `homeConfigurations = { }`. Either add a comment in `flake/default.nix` noting the standalone-HM path is load-bearing for a planned Arch host (per `hosts.nix`'s comment), or gate the import on `homeManagerHosts != { }`.
- [ ] **`darwin.nix` lacks `plasma-manager` `sharedModules` injection — undocumented intentional asymmetry.** [flake/nixos.nix](flake/nixos.nix#L34) injects `plasma-manager` into HM's `sharedModules` when `desktopEnvironment == "kde-plasma"`. [flake/darwin.nix](flake/darwin.nix#L30) has no equivalent. Correct (no Plasma on macOS), but a one-line comment would prevent a future contributor from "fixing" the asymmetry by copy-pasting it in.

### P4 — Module Quality

- [ ] **`flake/default.nix` exposes `systems` as a flake attribute with no consumers.** [flake/default.nix](flake/default.nix#L57) computes `systems` (a unique list of host platforms) and re-exports it. Nothing in the repo (no `formatter.<system>`, no `devShells`, no `packages`) consumes it. Either remove it, or wire it into a per-system `formatter` / `devShells` block so it earns its keep.

### P5 — Script & Documentation Polish

- [ ] **`flake/metadata.nix` header glosses over the filesystem-relative path.** [flake/metadata.nix](flake/metadata.nix#L20) header says the private overlay is "expected at `../nix-config-private/` relative to this repo root", but the implementation uses `../../nix-config-private/metadata.nix` relative to `flake/metadata.nix` and reads the live filesystem rather than `inputs.private`. Either rewrite the header to make this explicit (and explain why, vs `hosts.nix`'s input-based load), or — preferred — fix the implementation per the P1 entry above and leave the header alone.
- [ ] **`flake/hosts.nix` has no module-header comment.** [flake/hosts.nix](flake/hosts.nix#L1) is silent about the two registries (`nixosHosts`/`darwinHosts`/`homeManagerHosts`), the `mkHost` shape it returns (`{ configuration; home; userSettings; }`), and the public/private overlay merge. Add a short header matching the style of `flake/metadata.nix`.
