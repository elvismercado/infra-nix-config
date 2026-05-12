# nix-config — Improvement Backlog

Open items only.

## Backlog — Pending Decisions

### Display modules — parked, decide remove vs upgrade

- [ ] **`custom.sysNixPlymouth` + `custom.hmShutdownDisableOutputs` — improve before re-enabling (coupled).** Parked on JIN + FENNEC 2026-05-05. The shutdown-disable-outputs module exists _only_ to mitigate Plymouth's multi-monitor shutdown flicker, so the two are all-or-nothing: re-enable Plymouth (with fixes) → re-evaluate `hmShutdownDisableOutputs`; delete Plymouth permanently → also delete `hmShutdownDisableOutputs`. Issues to fix before re-enabling Plymouth:
  - `useSimpleDrm = false` workaround on JIN — amdgpu forced-SI ignores `video=<connector>:d`, so per-output suppression doesn't actually work. Need a real fix or remove the option.
  - `bootDisabledOutputs` mechanism is GPU-driver-dependent (works for some cards, ignored by amdgpu). Document supported drivers, or replace with a more reliable approach (e.g. early kscreen-doctor invocation).
  - Splash flickers/glitches at handoff to SDDM greeter — the new deterministic SDDM layout may help, but needs verification.
  - `minAnimationDuration = 3` is a hack to mask "boots faster than animation"; consider whether the splash adds value at all on a 5s NVMe boot.
  - Verify whether the multi-monitor shutdown flicker (the reason `hmShutdownDisableOutputs` exists) still occurs in current Plasma 6 / Plymouth. If fixed upstream, delete `hmShutdownDisableOutputs` and remove from HOME-MANAGER.md regardless of Plymouth outcome.
  - Re-enable plan: pick one host (FENNEC, simpler config), validate, then enable on JIN.
