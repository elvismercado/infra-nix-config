# nix-config — Improvement Backlog

Open items only.

## Backlog — Pending Decisions

### LULA — macOS → NixOS migration (Round 2)

- [ ] **LULA host rewrite (Lenovo ThinkPad T14 Gen 2 / Intel i5-1135G7).** Round 1 (specs + cross-host docs) is done — see [hosts/LULA/README.md](hosts/LULA/README.md). Round 2 must:
  - Install NixOS 25.11 stable, x86_64-linux, on the laptop. Decide whether [scripts/nixos/install.sh](scripts/nixos/install.sh) covers a single-NVMe laptop layout or needs a per-host variant (no second drive for `/home`, no hibernation-sized swap unless you want sleep-to-disk).
  - Capture `hosts/LULA/configuration/hardware-configuration.nix` from `nixos-generate-config --show-hardware-config`.
  - Rewrite `hosts/LULA/configuration/` for NixOS: KDE Plasma + SDDM, NetworkManager, Bluetooth, PipeWire, fprintd (fingerprint reader), TLP or power-profiles-daemon (laptop battery tuning), backlight / lid-switch handling, microSD reader. Drop `users.knownUsers`, Homebrew, casks, `system.primaryUser`.
  - Rewrite `hosts/LULA/home-manager/` to import Linux modules (no darwin wrappers, no Rectangle).
  - Swap the Brave façade from `modules/apps/darwin/brave.nix` to `modules/apps/linux/brave.nix`. Keep `custom.appBrave.extensions = []` (vanilla policies, no force-installed extensions).
  - Swap LocalSend façade from darwin to linux. AppCleaner has no Linux equivalent — drop entirely.
  - Update `hosts/LULA/user-settings.nix`: `uid = 1000` (or whatever `id -u lula` returns post-install).
  - Flip `hosts/LULA/metadata.nix`: `os = "nixos"` and remove the TEMPORARY block from the header.
  - Move LULA in [flake/hosts.nix](flake/hosts.nix) from `darwinHosts` to `nixosHosts`.
  - Verify cross-host doc tables (DARWIN.md / HOME-MANAGER.md / NIXOS.md / README.md) still match reality after the flip.
  - Note known Linux-side losses: IR-camera face unlock (no equivalent), AppCleaner (no equivalent).

### Display modules — parked, decide remove vs upgrade

- [ ] **`custom.sysNixPlymouth` + `custom.hmShutdownDisableOutputs` — improve before re-enabling (coupled).** Parked on JIN + FENNEC 2026-05-05. The shutdown-disable-outputs module exists _only_ to mitigate Plymouth's multi-monitor shutdown flicker, so the two are all-or-nothing: re-enable Plymouth (with fixes) → re-evaluate `hmShutdownDisableOutputs`; delete Plymouth permanently → also delete `hmShutdownDisableOutputs`. Issues to fix before re-enabling Plymouth:
  - `useSimpleDrm = false` workaround on JIN — amdgpu forced-SI ignores `video=<connector>:d`, so per-output suppression doesn't actually work. Need a real fix or remove the option.
  - `bootDisabledOutputs` mechanism is GPU-driver-dependent (works for some cards, ignored by amdgpu). Document supported drivers, or replace with a more reliable approach (e.g. early kscreen-doctor invocation).
  - Splash flickers/glitches at handoff to SDDM greeter — the new deterministic SDDM layout may help, but needs verification.
  - `minAnimationDuration = 3` is a hack to mask "boots faster than animation"; consider whether the splash adds value at all on a 5s NVMe boot.
  - Verify whether the multi-monitor shutdown flicker (the reason `hmShutdownDisableOutputs` exists) still occurs in current Plasma 6 / Plymouth. If fixed upstream, delete `hmShutdownDisableOutputs` and remove from HOME-MANAGER.md regardless of Plymouth outcome.
  - Re-enable plan: pick one host (FENNEC, simpler config), validate, then enable on JIN.

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
