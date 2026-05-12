# nix-config — Improvement Backlog

Comprehensive audit findings for iterative improvement. Check items off as they are completed.

---

## Completed — Round 1

<details>
<summary>P1–P5: 43 items (all completed)</summary>

### P1 — Security & Correctness

- [x] **install.sh: Hardcoded UID 1000:100** — `deploy_repo()` uses `chown -R 1000:100`. Read from `user-settings.nix` `uid` field instead.
- [x] **install.sh: No disk space validation** — EFI + swap + home could exceed disk size, causing confusing `parted` errors. Validate before destructive operations.
- [x] **install.sh: Late `--host` validation** — `--host` value not validated until `resolve_username()`. User goes through disk prompts before learning the host doesn't exist. Validate right after `clone_repo`.
- [x] **ssh-server.nix: Permissive SSH defaults** — `PasswordAuthentication = true` and `AllowUsers = null` (allows all users). Consider key-only default or restrict `AllowUsers` to `userSettings.username`.

### P2 — Robustness & Reliability

- [x] **install.sh: Replace `sleep 2` with `udevadm settle`** — After `partprobe`, use `udevadm settle` for deterministic partition readiness instead of a fixed sleep.
- [x] **install.sh: Add cleanup trap on failure** — If the script fails mid-install, mounts under `/mnt` are left active. Add a trap that runs `umount -R /mnt; swapoff -a` on ERR exit.
- [x] **install.sh: Replace `eval` with `printf -v`** — `prompt_size` and `prompt_disk` use `eval` to set variables by name. `printf -v "$varname" '%s' "$value"` is safer.
- [x] **install.sh: Validate minimum EFI partition size** — A user could specify `--efi-size 1M` which is too small for FAT32. Enforce a minimum.
- [x] **postinstall.sh: Validate hostname matches flake host** — `hostname` could differ from the flake host name. Check `hosts/${HOST}/` exists before `nixos-rebuild`.
- [x] **postinstall.sh: Add `--title` to `gh ssh-key add`** — Won't fix: `gh ssh-key add` already uses the key comment (`${USER}@hostname-date`) as the GitHub title automatically.
- [x] **postinstall.sh: Validate not running as root** — `passwd` and `$HOME` would target the wrong user if run as root.

### P3 — Architecture & Convention

- [x] **Remove unused `mac-app-util` flake input** — Declared in `flake.nix` but never consumed in any module. Adds to `flake.lock` weight and update time.
- [x] **Add `determinate` darwin module to EDGE** — `flake/nixos.nix` includes `determinate.nixosModules.default` for NixOS hosts. `flake/darwin.nix` is missing `determinate.darwinModules.default` for EDGE.
- [x] **Document `plasma-manager` stable-only constraint** — `plasma-manager` follows `nixpkgs-stable` / `home-manager-stable`. If a NixOS host ever uses `channel = "unstable"`, there will be a version mismatch.
- [x] **Make `plasma-manager` conditional on DE** — Currently loaded for all NixOS hosts via `home-manager.sharedModules` regardless of desktop environment. Should be conditional.
- [x] **Remove dead `garbage.nix` import from EDGE** — `hosts/EDGE/configuration/default.nix` imports `garbage.nix` but it can never be enabled (`nix.enable = false`). Remove the import.
- [x] **Use `userSettings.system` for EDGE `hostPlatform`** — `hosts/EDGE/configuration/configuration.nix` hardcodes `"x86_64-darwin"` instead of using `userSettings.system`.
- [x] **Extract duplicated switch aliases to shared module** — `switch`, `switchbuild`, `switchtest`, `switchhealth`, `switchhelp` are copy-pasted across all 3 host `home.nix` files. Extract to a shared module with a platform toggle.
- [x] **Move duplicated `trusted-users` to flake-level builder** — `nix.settings.trusted-users` is identical in both NixOS `user.nix` files. Move to `flake/nixos.nix`.
- [x] **Make repo path configurable** — `~/git/nix-config` is hardcoded in `postinstall.nix`, `aliases.nix` (`switchcd`, `switchupdate`, `switchcheck`). Add a configurable option with this as the default.

### P4 — Module Quality

- [x] **Add comment headers to 13 modules** — Missing purpose + Usage block: `base.nix`, `packages.nix`, `vscode.nix`, `bash.nix`, `brave.nix`, `syncthing.nix`, `thunderbird.nix`, `nextcloud.nix`, `docker.nix`, `mullvad.nix`, `garbage.nix` (shared), `packages.nix` (shared), partial `aliases.nix`.
- [x] **Standardise option prefixes** — All modules now use prefixed naming: `hm*` (home-manager), `sys*` (shared system), `sysDar*` (darwin system), `sysNix*` (NixOS system). Updated all module files, host configs, and documentation.
- [x] **Deduplicate `nil` package** — Removed from `vscode.nix`; kept in `base.nix` where it's available to all hosts.
- [x] **Remove `mpv` from `packages.nix`** — Removed from `packages.nix`; JIN now imports `mpv.nix` module (FENNEC already had it, EDGE uses Homebrew brew).
- [x] **Move Linux-only packages from `all/packages.nix` to `linux/`** — Created `linux/packages.nix` (`custom.hmLinuxPackages`) with 6 Linux-only packages; `all/packages.nix` now only has cross-platform packages.
- [x] **Add platform guard to `vscode.nix` and `nextcloud.nix`** — Moved both from `all/` to `linux/`. macOS hosts use Homebrew casks instead.
- [x] **Move AMD/NVIDIA aliases from `all/` to `linux/`** — Moved `hmAliasesAmdCpu`, `hmAliasesNvidiaGpu`, and `nixdiag` to `linux/aliases.nix`. All use Linux-only commands.
- [x] **Move `cowsay`/`lolcat` out of `base.nix`** — Moved to `all/packages.nix`, then merged `all/packages.nix` into `all/base.nix` (eliminated redundant module). Moved 4 GUI apps (`localsend`, `mullvad-vpn`, `handbrake`, `moonlight-qt`) to `linux/packages.nix` to avoid Homebrew conflicts on macOS.
- [x] **Make `EDITOR` configurable in `base.nix`** — Added `custom.hmBase.editor` option (default `"nano"`). Used by `base.nix` (`EDITOR` env var) and `git.nix` (`core.editor`).
- [x] **Use declarative `programs.thunderbird` in `thunderbird.nix`** — Switched from raw `home.packages` to `programs.thunderbird.enable` with a default profile. Removed commented-out account config. Hunspell dictionaries kept in `home.packages`.
- [x] **Clean up commented-out code** — Removed dead commented-out blocks from 8 files: `vscode.nix` (editor/formatter settings), `sunshine.nix` (preset config), `syncthing.nix` (optional settings), `bash.nix` (`shellOptions`), `nextcloud.nix` (`startInBackground`), `linux/packages.nix` (alt packages), `base.nix` (headsetcontrol variants), `aliases.nix` (dead aliases). Kept deliberate notes with inline explanations.
- [x] **Conditionally enable `plasma-browser-integration` in `brave.nix`** — Auto-detects `desktopEnvironment = "kde-plasma"` from `userSettings` and includes `plasma-browser-integration` in `nativeMessagingHosts`.
- [x] **Add docker group membership to `docker.nix`** — Module now adds the user to the `docker` group automatically via `userSettings.username`. Removed redundant manual entry from JIN's `user.nix`.
- [x] **Add Determinate Nix guard to shared `garbage.nix`** — Auto-disables GC/optimise when `nix.enable = false` (Determinate Nix hosts). Enabling `custom.sysGc` is a safe no-op on those hosts.
- [x] **Add comment for `syncthing.nix` `urAccepted = -1`** — Added inline comment explaining `-1` means opt-out of anonymous usage reporting.

### P5 — Script Polish

- [x] **install.sh: Handle `/tmp/nix-config` collision** — Stale `/tmp/nix-config` from interrupted runs is now removed before cloning. Replaced unreliable `git pull` fallback with delete + fresh clone.
- [x] **install.sh: Add error check after `git clone`** — Added explicit `fatal` message on clone failure instead of relying on cryptic `set -e` exit.
- [x] **install.sh: Gitignore `INSTALL-REPORT.md`** — Already gitignored (`**/INSTALL-REPORT.md` in `.gitignore`).
- [x] **setup.sh: Add timeout to `xcode-select --install` polling** — Added 15-minute timeout (180 iterations × 5s). Exits with a clear error and manual install instructions if timed out.
- [x] **setup.sh: Align clone method with `install.sh`** — Switched from `gh repo clone` (requires auth) to `git clone` with HTTPS URL. Existing repo prompts user before deletion. Added clone failure error check.
- [x] **bash.nix: Remove debug echo** — Won't fix: echos are intentional hook references. All four `programs.bash` hooks (`bashrcExtra`, `initExtra`, `profileExtra`, `logoutExtra`) are covered.
- [x] **JIN `default.nix`: Fix stale `gfxmodeEfi` comment** — Updated value to full resolution chain (`3840x2160,2560x1440,1920x1200,1920x1080,auto`) and fixed comment. Removed stale commented-out line.
- [x] **Move group membership into system modules** — `libvirtd` and `adbusers` auto-added by their modules. Created `embedded.nix` (`custom.sysNixEmbedded`) for `dialout` group + `arduino-ide`. Removed all three from JIN's `user.nix`.

</details>

---

## Round 2

### P1 — Security & Correctness

- [x] **install.sh: Validate extracted USERNAME** — `resolve_username()` now validates `USERNAME` matches `^[a-z_][a-z0-9_-]{0,31}$` (POSIX) and `USER_UID` is in range 1000–65533. Defense-in-depth before values are interpolated into shell paths.
- [x] **install.sh: Add timeout to `udevadm settle`** — Both `udevadm settle` calls now use `--timeout=30` to fail fast on a stuck udev queue instead of hanging silently for 3 minutes.
- [x] **flake/hosts.nix: Assert valid channel value** — `mkHost` now validates `userSettings.channel` is `"stable"` or `"unstable"` and `throw`s a clear error at flake evaluation otherwise. Catches typos before any rebuild starts.

### P2 — Robustness & Reliability

- [x] **install.sh: Validate `nixos-generate-config` output** — `generate_hardware_config()` now fails fast with a clear message if the command fails, the file is empty, or the file is missing `fileSystems` definitions.
- [x] **install.sh: Use `mktemp` for temporary repo** — `clone_repo()` now uses `mktemp -d -t nix-config.XXXXXX` for a unique, race-free path with restrictive permissions. Eliminates symlink attack surface and concurrent-install collisions.
- [x] **setup.sh: Validate Determinate Nix installer download** — Both Determinate Nix and Homebrew installers now use download-then-execute via `mktemp` + `curl -fsSL -o` + non-empty check + trap-based cleanup. Eliminates silent failure when `curl | sh` pipes an empty/partial script.

### P3 — Architecture & Convention

- [x] **Add comment headers to 16 modules** — All 16 modules now have the standard header (purpose + brief explanation + Usage block) matching the existing convention used by `brave.nix`, `hmBash`, etc.
- [x] **Remove unnecessary `lib.mkDefault` on NixOS home.nix** — Dropped `lib.mkDefault` from `home.username` and `home.homeDirectory` in FENNEC and JIN `home.nix`; both now match EDGE's plain assignment. Removed unused `lib` arg.
- [x] **Add section comments to EDGE home-manager imports** — EDGE `home-manager/default.nix` now uses the same `# Host`, `# Base`, `# Shell`, `# Apps`, `# macOS` section comments as FENNEC/JIN, in both the `imports` and `custom.hm*.enable` blocks.
- [x] **Add section comments to EDGE configuration imports** — EDGE `configuration/default.nix` now uses `# Host`, `# Darwin / UI`, `# Darwin / System`, `# Shared` section comments in both the `imports` and `custom.*.enable` blocks.

### P4 — Module Quality

- [x] **Decide host-level module coverage** — Reviewed and confirmed current state is intentional: dev tools (`fnm`, `pyenv`, `ansible`) on JIN + EDGE (dev hosts), absent on FENNEC (gaming/media). Syncthing on FENNEC + JIN via `hmSyncthing`; EDGE uses the `syncthing-app` Homebrew cask per the macOS-GUI-via-cask convention. Per-host `default.nix` is the install manifest.
- [x] **enable-flakes.nix: Clean up stale comments** — Verified: the file already has the standard header (purpose, Determinate Nix note, Usage block). No stale commented-out examples remain. No code change needed.
- [x] **Deduplicate FENNEC/JIN `user.nix`** — Extracted shared user account config to `modules/systems/nixos/system/user.nix` (`custom.sysNixUser.enable` + optional `extraGroups`). Deleted `hosts/FENNEC/configuration/user.nix` and `hosts/JIN/configuration/user.nix`; both hosts now enable the new module from `default.nix`. NIXOS.md updated.
- [x] **Deduplicate FENNEC/JIN `configuration.nix`** — Folded `networking.networkmanager.enable` into `sysNixUser` (paired with the `networkmanager` group). `nixpkgs.config.allowUnfree` was already centralized in `flake/nixos.nix`; `programs.nix-ld` is not used; `system.stateVersion` intentionally stays per-host (locked to first install).

### P5 — Script & Documentation Polish

- [x] **INSTALL.md: Align manual steps with automated script** — Removed duplicate `SWAP_MIB`/`HOME_MIB` variables from Step 0 (now derived from `*_SIZE` via `numfmt`, mirroring `size_mib()` in install.sh). Added `-F` to `mkfs.ext4` and `partprobe` + `udevadm settle --timeout=30` after each parted block, matching the script.
- [x] **README.md: Document channel selection** — Expanded the channel table with the `nix-darwin` input row, added a 'Switching a host's channel' subsection (edit `user-settings.nix` → rebuild), and added a Quickstart pointer noting hosts default to `stable`.
- [x] **setup.sh: Consistent error handling pattern** — Added a `fatal()` helper at the top (matching `install.sh`'s style) and replaced all `|| { echo "...ERROR..."; exit 1; }` blocks and the bare xcode-select `exit 1` with `|| fatal "..."`. Single uniform pattern throughout.

---

## Round 3

### P1 — Security & Correctness

- [x] **setup.sh: `local` keyword incompatible with `#!/bin/sh`** — Switched shebang to `#!/bin/bash` (matches `install.sh`). Resolves the dash incompatibility for the three `local` declarations.

### P2 — Robustness & Reliability

- [x] **EDGE enables `hmAndroid` but adb/scrcpy use is unusual on macOS** — Confirmed intentional: adb/scrcpy are used on EDGE for Android device work. Added an inline comment next to the enable line to document the rationale.
- [x] **`scripts/windows/` directory referenced in README but missing on disk** — Phantom finding: nothing in the actual repo references `scripts/windows/` (the workspace metadata listing it was stale). No code change needed.

### P3 — Architecture & Convention

- [x] **copilot-instructions.md: stale `userSettings` field list** — Updated the Host Wiring section to include `repoPath` (all hosts) and `desktopEnvironment` (optional, e.g. `"kde-plasma"`; consumed via `or null`).
- [x] **copilot-instructions.md contradicts README/HOME-MANAGER.md on `home-manager switch`** — copilot-instructions.md was correct (standalone HM is not wired up since `homeManagerHosts` is empty). Removed misleading `home-manager switch` examples from `README.md` Quick Commands, `HOME-MANAGER.md` (rewrote intro/Switch/How It Works to reflect system-module integration), and `add-host.prompt.md` (per-host README template + flake entry comment). `homeManagerHosts` stays reserved for future non-NixOS/non-darwin hosts.
- [x] **EDGE `user-settings.nix` missing `desktopEnvironment` field** — Added `desktopEnvironment = null; # macOS — DE managed by the OS` so all hosts declare the same schema. Consumers already handle `null` via `or null`.

### P4 — Module Quality

- [x] **`android.nix` lives in `all/` but is Linux/Android-developer focused** — Resolved by Round 3 P2 #1: EDGE confirmed as a genuine consumer (adb/scrcpy used for device work on macOS), so module stays in `all/`. Added a one-line cross-platform note to the module header.
- [x] **`postinstall.nix` doesn't validate `userSettings.repoPath` shape** — Added a `config.assertions` entry requiring `repoPath` to be a non-empty relative string with no leading `/` and no `..` segments. Produces a clear build-time error instead of a silent broken alias.

### P5 — Script & Documentation Polish

- [x] **README.md repository structure: stale module listings** — Added `embedded` to the `nixos/apps/` listing and `user` to the `nixos/system/` listing so README matches the current tree.

## Round 4

### P3 — Architecture & Convention

- [x] **README.md: home-manager module listings under wrong section** — Moved `Nextcloud`, `Packages`, and `VS Code` from the `all/` listing to `linux/` to match actual file locations.

### P4 — Module Quality

- [x] **Vague `mkEnableOption` descriptions across 8 modules** — Rewrote descriptions in brave, bash, ansible, thunderbird, syncthing, nextcloud, vscode, and sunshine to summarise what each module actually configures (matching its header comment).

## Round 5

### P3 — Architecture & Convention

- [x] **`mkEnableOption "enables ..."` prefix violates style guide and produces ungrammatical generated docs (93 modules)** — Stripped the `"enables "` prefix from all 93 modules across `modules/home-manager/` and `modules/systems/` and rewrote each description to summarise what the module configures (matches the header comment). Verified with grep: zero remaining instances.

## Round 6

### P2 — Robustness & Reliability

- [x] **`shutdown-disable-outputs.nix`: enabling with empty `connectors` was a silent no-op and bypassed the KDE assertion** — Split the `config` block: assertions (KDE Plasma + non-empty connectors) now run on `cfg.enable` alone, while the systemd user service still requires connectors. Misconfig now fails at evaluation time instead of silently doing nothing.

## Round 7

### P2 — Robustness & Reliability

- [x] **Install scripts hardcoded `git/nix-config` while `userSettings.repoPath` exists to make this configurable** — `install.sh` now reads `repoPath` from the host's `user-settings.nix` (same sed pattern as `username`/`uid`, with the same shape validation as `modules/systems/nixos/postinstall.nix`'s assertion). `postinstall.sh` now derives `REPO_DIR` from its own script path (`readlink -f "$0"` → up 3 levels), so it always uses whatever path the user chose without re-parsing. Both scripts now honour `repoPath` end-to-end.

## Round 8

### P3 — Architecture & Convention

- [x] **`modules/systems/shared/ssh-server.nix` has no current consumer** — Module defines `custom.sysSshServer.{enable,passwordAuth}` and is documented in NIXOS.md/DARWIN.md/HOME-MANAGER.md but no host imports or enables it. Decision: **kept as-is** — intentionally dormant, ready for opt-in on any host that needs inbound SSH. No code change.
- [x] **`modules/systems/nixos/nix/garbage.nix` missing header comment** — Every other module follows the standard purpose / explanation / Usage header convention; this NixOS-specific wrapper jumped straight to the function. Added a header noting it layers `nix.gc` scheduling and `nix.optimise.randomizedDelaySec` on top of `shared/garbage.nix`.

### P4 — Module Quality

- [x] **`modules/home-manager/all/base.nix` declared unused `userSettings` arg** — The function signature took `userSettings,` but nothing in the config body referenced it. Removed the argument so the module's function signature reflects its actual dependencies.

## Round 9

### P5 — Script & Documentation Polish

- [x] **FENNEC README's "Next steps" had a stale manual `resumeDevice` instruction** — Step 3 told the user to set `custom.sysNixHibernate.resumeDevice` to the swap UUID, but `modules/systems/nixos/memory/hibernation.nix` has auto-derived `resumeDevice` from `swapDevices` since Round 4. Dropped the step entirely — the explicit override is now an edge-case escape hatch (swap files), documented in the module header, not a normal install step.

## Round 10

### P3 — Architecture & Convention

- [x] **Four NixOS modules missing or incomplete header comments** — Round 2's header sweep missed `system/time.nix`, `system/i18n.nix`, `system/fonts.nix`, and `desktop_environment/cosmic.nix`. Added the standard `# Purpose / explanation / Usage:` block to each, tailored to what the module actually configures (timezone from userSettings, en_GB+nl_NL locale layering, NixOS-specific fontconfig over `shared/fonts.nix`, and the COSMIC desktop+cachix binary cache respectively).

## Round 11

No findings — deep dive across per-host configs, vscode/fnm/pyenv shell-init, plasma vs window-shortcuts, postinstall.sh idempotency, security/, and gaming/ returned clean.

## Round 12

### P1 — Security & Correctness

- [x] **Round 10 header-add edits silently deleted `options` blocks in `cosmic.nix` and `i18n.nix`** — The `multi_replace_string_in_file` calls used an `oldString` that included the `options = { ... }` block but a `newString` that ended at the function-args closing `}:`, dropping the body in between. Both modules had an orphan `};` and referenced `enable` flags that no longer existed; `nix flake check` would fail. Restored the `options` blocks in both files. `time.nix` and `fonts.nix` from the same batch were unaffected because their replacements didn't span the body. Recorded the pattern in user memory (`/memories/nix-edit-pitfalls.md`) so I check the first 20 lines after any header-add batch.
- [x] **Round 8 header-add edit silently deleted `imports` + `config = lib.mkIf` block in `nix/garbage.nix`** — Same bug pattern as the Round 10 regressions, found while auditing all session-edited files post-fix. The header-add `oldString` swallowed the opening `{`, the `imports = [ ../../shared/garbage.nix ]`, and the `config = lib.mkIf` line, leaving function args `}:` jumping straight to a free-floating `nix.gc = {` with mismatched braces. Restored the missing block; the module would have failed `nix flake check` on JIN and FENNEC (both enable `custom.sysGc`).

## Round 13

No findings. Deep dive across `.github/instructions/`, `.github/prompts/`, flake input follows, per-host `user-settings.nix`, `kde_plasma.nix`, `git.nix`, `darwin/system-preferences.nix`, `display-profiles.nix`, and a regex sweep for the Round 12 bug pattern across all modules.

Decision logged: `git.nix` builds `user.email` as `"${userSettings.username}@${userSettings.hostname}"` (e.g. `jin@JIN`) — confirmed intentional, not a defect. Future audits should not re-flag this.

## Round 14

### P1 — Security & Correctness

- [x] **DARWIN.md and NIXOS.md "Adding a New Host" templates were missing required `user-settings.nix` fields** — Both templates showed only 5 fields (`username`, `hostname`, `system`, `channel`, `timeZone`) but the actual host configs and `copilot-instructions.md` document 8: adding `uid`, `repoPath`, and `desktopEnvironment`. A new user following either template would have hit errors (`user.nix` reads `userSettings.uid`; `postinstall.nix` asserts `repoPath` shape). Updated both templates to show the full set with realistic sample values and comments — Darwin uses `uid = 501` and `desktopEnvironment = null`; NixOS uses `uid = 1000` and `desktopEnvironment = "kde-plasma"`.

### P3 — Architecture & Convention

- [x] **DARWIN.md "Adding a New Darwin Host" directory tree omitted `homebrew.nix`** — EDGE now uses `hosts/EDGE/configuration/homebrew.nix` as the recommended pattern for separating Homebrew package management from host wiring. Added `homebrew.nix` to the example tree with an inline comment marking it as recommended (with pointer to EDGE) so future Mac hosts follow the same split rather than putting the homebrew block inline.

## Round 15 — PII Audit

Read-only inventory of personally-identifiable / sensitive data exposed by the public GitHub mirror. Scoped to the working tree (includes `.archive/`, excludes `.git/`). Severity reflects public-disclosure risk; items are mapped to existing P1-P3 buckets (P1 = HIGH, P2 = MEDIUM, P3 = LOW). Findings only — each item ships with a suggested fix to be triaged and applied one-by-one in follow-up sessions.

Suggested order of work: do the `.gitignore` guards first, then the metadata split, then secondary items. That way any new `*.local.nix` is auto-ignored from the moment it's created.

### P1 — Security & Correctness (HIGH)

- [x] **`.gitignore` has no guard against accidental secret commits** — `.gitignore` currently only contains `**/INSTALL-REPORT.md`. Any future `*.local.nix`, `secrets/`, `.env`, agenix `*.age`, or sops `*.yaml` would be committed by default. **Fix:** before introducing the metadata split below, add explicit guard patterns: `*.local.nix`, `secrets/`, `.env`, `.env.*`, `*.age`, `*.gpg`. Add a `!*.example.local.nix` allow-line so committed templates stay tracked. **Resolved:** added the 6 guard patterns + `!*.example.local.nix` allow-line to `.gitignore` under a `# Secrets / local-only files` heading, with an inline comment pointing back to this round and explaining the `*.example.local.nix` template convention. Pre-verified no currently-tracked file matches any new pattern.
- [ ] **LAN IPv4 addresses exposed across all metadata** — Every `hosts/*/metadata.nix` encodes a real internal IP (JIN `192.168.1.10`, EDGE `192.168.1.50`, YUNA `192.168.40.2`, SLIME `192.168.60.3`, LaJuvePixel6 `192.168.1.30`, LaJuvePixel9 `192.168.1.31`, plus FENNEC) plus Syncthing peer addresses inside `syncthing.addresses`. Together they reveal full internal topology including VLAN segmentation (`192.168.40.*`, `192.168.60.*`). **Fix:** split each `metadata.nix` into a public stub (hostname, managed, os, optional syncthing.id) + a gitignored `metadata.local.nix` (or `secrets/<host>.nix`) holding `lanIp` + `syncthing.addresses`. Update `flake/metadata.nix` to merge optionally (`builtins.pathExists`-guarded import). LULA already ships `lanIp = null` — use it as the shape exemplar.
- [ ] **Syncthing device IDs are persistent device fingerprints** — Five IDs in tree: EDGE (`57HA3EL-…-LYNOMAX`), FENNEC (`OPSABBX-…-XM5ZYAB`), YUNA (`E25DNYB-…-KFNU5AL`), SLIME (`R6BJ3B2-…-SXWD5AJ`), LaJuvePixel9 (`E2ZNFF2-…-NWJLCAU`). Once published they are forever a stable identifier mapping the repo to specific physical machines via global Syncthing discovery. **Fix:** move IDs into the same gitignored split as `lanIp`. **Mitigation:** anything already pushed is exfiltrated — regenerate each device's Syncthing identity (delete `cert.pem`+`key.pem`, restart) after the split lands, then update the new local files. Rotation disrupts every peer (re-pair on each device); schedule for a quiet evening.

### P2 — Robustness & Reliability (MEDIUM)

- [ ] **Real first names baked into usernames + comments** — `hosts/EDGE/user-settings.nix` (`username = "elvis"`), `hosts/LULA/user-settings.nix` (`username = "maria"`), and "Maria's …" descriptors in `hosts/LULA/metadata.nix` header + `hosts/LULA/README.md`. JIN/FENNEC use pet-style names and are unaffected. **Fix:** decision required. Renaming a macOS user is non-trivial (`/Users/<old>` won't auto-rename, Brave Sync / iCloud / Homebrew prefixes break). Two options — (a) keep usernames, strip "Maria's …" descriptors in favour of role wording ("primary user", "secondary daily-driver"); (b) plan a coordinated rename to neutral handles (`edge`, `lula`) at the next OS reinstall. Recommend (a) for now; revisit (b) for LULA before the device arrives so it ships clean.
- [ ] **Disk / swap UUIDs in `hardware-configuration.nix`** — `hosts/JIN/configuration/hardware-configuration.nix` and `hosts/FENNEC/configuration/hardware-configuration.nix` use `by-uuid` paths for `/`, `/boot`, swap. NixOS effectively requires these for `fileSystems.*.device`; flagging because they uniquely identify the physical drives and tie commits to a specific machine. **Fix:** no action — accept as required exposure. Add a one-line header note to each `hardware-configuration.nix` documenting the accepted-disclosure decision so future audits don't re-flag. Spot-check that no UUID appears outside `hardware-configuration.nix` (none today; re-verify when P1 split lands).
- [ ] **Hardware fingerprint detail in per-host READMEs** — `hosts/JIN/README.md`, `hosts/FENNEC/README.md`, `hosts/EDGE/README.md`, `hosts/LULA/README.md` document exact RAM model (e.g. Corsair CMK32GX4M2B3200C16), specific SSD model+capacity, GPU+VRAM, monitor firmware revision. Combined with timezone and GitHub handle this narrows physical-machine identification. **Fix:** decision per host. Recommend keeping JIN/FENNEC verbose (desktops, rarely visible publicly) and trimming EDGE/LULA to generic class strings ("32 GB DDR4-3200", "1 TB NVMe SSD", "RTX 3080-class") — they're laptops, travel-photographable.

### P3 — Architecture & Convention (LOW)

- [ ] **Timezone `Europe/Amsterdam` in every `user-settings.nix`** — Broad regional disclosure (CET/CEST spans ~25 countries). Acceptable in isolation; flagged for completeness. **Fix:** no action; record as accepted exposure so future audits don't re-surface.
- [ ] **Cloud-service app intent (no credentials)** — Modules enabling Nextcloud, Insync (Google Drive), Proton Mail Bridge, Mullvad VPN, Syncthing reveal which third-party services the user has accounts with. No URLs / tokens / account hints are committed; the inference is purely "user has these accounts". **Fix:** no action — these modules ARE the install intent. Documented as accepted exposure.
- [ ] **Git history may contain pre-cleanup leaks** — Out of scope for working-tree audits; commit history and old refs can contain values deleted from `main`. **Fix:** before the next public push (or before applying the P1 metadata split), run locally: `git log --all -S "192.168" --oneline`, `git log --all -S "<one syncthing ID prefix>" --oneline`, `git log --all --grep -iE "password|secret|token|credential"`. If hits exist in old commits, evaluate `git filter-repo` rewrite vs accept-and-rotate. **Mitigation:** any IP / Syncthing ID already on `main` is already public regardless of cleanup — rotation is the only real fix.
- [ ] **No backstop for future contributors / future-self** — No `CONTRIBUTING.md` / `SECURITY.md` / repo-level note describing the "no secrets in tree" rule, the `*.local.nix` split, or the pre-push checklist. **Fix:** after the P1 items are resolved, add a short section in `README.md` (or a header comment in each `metadata.nix` template) pointing at the local-file split and the pre-push `git log -S` check. Keep it lightweight — single-maintainer repo.

## Backlog — Pending Decisions

Items outside the audit-round cadence; ad-hoc enhancements awaiting a decision.

### Display modules — parked, decide remove vs upgrade

- [x] **`custom.sysNixSddmMonitorLayout` — decide: remove or upgrade.** Module: `modules/systems/nixos/display_manager/sddm-monitor-layout.nix`. Status: zero hosts enable it. Activation script copies a runtime-mutated `~/.config/kwinoutputconfig.json` to the SDDM user; fragile (file may not exist on fresh install, mid-session edits not captured until next rebuild). Either delete and remove from NIXOS.md table, or rework to derive layout declaratively. **Resolved 2026-05-05**: rewrote as deterministic two-module pipeline. New `custom.hmSddmMonitorLayout` (home-manager) renders `kwinoutputconfig.json` at evaluation time from `custom.hmDisplayProfiles.profiles.<name>` via internal helper `_sddm-kwin-render.nix`. Rewritten `custom.sysNixSddmMonitorLayout` (system) just `cp`s the rendered store path into `/var/lib/sddm/.config/`. No jq, no runtime scrape, no auto-detect. Wired on JIN (`profile = "m1-4k"`, disabled DP-2) and FENNEC (`profile = "m1-4k"`).

- [x] **FENNEC `hmDisplayProfiles` — define profiles or remove module enable.** Defined 11 profiles in `hosts/FENNEC/home-manager/default.nix` covering all 7 topology combinations (M1, M2, M3, M1+M2, M1+M3, M2+M3, M1+M2+M3) × M1's two hardware modes (4K@160Hz scale 1.7, 1080p@320Hz scale 1.0). Module extended with `primary` flag so M1 stays primary across topology changes. M2 portrait left of M1, M3 right of M2.

- [ ] **`custom.sysNixPlymouth` + `custom.hmShutdownDisableOutputs` — improve before re-enabling (coupled).** Parked on JIN + FENNEC 2026-05-05. The shutdown-disable-outputs module exists _only_ to mitigate Plymouth's multi-monitor shutdown flicker, so the two are all-or-nothing: re-enable Plymouth (with fixes) → re-evaluate `hmShutdownDisableOutputs`; delete Plymouth permanently → also delete `hmShutdownDisableOutputs`. Issues to fix before re-enabling Plymouth:
  - `useSimpleDrm = false` workaround on JIN — amdgpu forced-SI ignores `video=<connector>:d`, so per-output suppression doesn't actually work. Need a real fix or remove the option.
  - `bootDisabledOutputs` mechanism is GPU-driver-dependent (works for some cards, ignored by amdgpu). Document supported drivers, or replace with a more reliable approach (e.g. early kscreen-doctor invocation).
  - Splash flickers/glitches at handoff to SDDM greeter — the new deterministic SDDM layout may help, but needs verification.
  - `minAnimationDuration = 3` is a hack to mask "boots faster than animation"; consider whether the splash adds value at all on a 5s NVMe boot.
  - Verify whether the multi-monitor shutdown flicker (the reason `hmShutdownDisableOutputs` exists) still occurs in current Plasma 6 / Plymouth. If fixed upstream, delete `hmShutdownDisableOutputs` and remove from HOME-MANAGER.md regardless of Plymouth outcome.
  - Re-enable plan: pick one host (FENNEC, simpler config), validate, then enable on JIN.
