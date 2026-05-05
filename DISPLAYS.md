# Displays

Shared monitor / KVM / TV topology across hosts. Per-host display details
live in each host's README.

## Monitors

| Tag | Model                  | Native                | Notes                                           |
| --- | ---------------------- | --------------------- | ----------------------------------------------- |
| M1  | Gigabyte M27U          | 3840×2160 @ 160 Hz    | Main monitor on desktop, 4K                     |
| M2  | Dell P2425 (fw M2B102) | 1920×1200 @ 60/100 Hz | Secondary, used in **portrait** (rotated right) |
| TV  | Samsung 55Q70R         | 3840×2160 @ 60 Hz     | Long HDMI from FENNEC only                      |

### EDID quirk — TV

The Samsung 55Q70R's max EDID mode is reported as **4096×2160**, not 3840×2160.
Display profiles that target this output must use `4096x2160` as the match key
even though the rendered resolution is 3840×2160. See
[hosts/FENNEC/home-manager/default.nix](hosts/FENNEC/home-manager/default.nix).

## KVM

[Level1Techs 1.4 DisplayPort KVM — Dual Monitor, Four Computer](https://www.store.level1techs.com/products/p/14-display-port-kvm-dual-4computer-kllrb-mfj5x)

- 2× DisplayPort 1.4 outputs (per active PC), 8× DP 1.4 inputs (2 per PC × 4 PCs)
- USB 3.0 + USB-HID switching
- **No monitor emulation** — displays re-handshake on every PC switch; windows
  shuffle unless mitigated at OS level
- _Intelligent EDID Engine_ for HDCP rekeying, but does **not** spoof EDID when
  an input is inactive
- The KVM has no inherent M1/M2 port assignment. Convention used in this repo:
  - **Bottom DP ports = M1 chain**
  - **Top DP ports = M2 chain**

## PC slot map

| KVM PC | Host   | Machine                                                                                            |
| ------ | ------ | -------------------------------------------------------------------------------------------------- |
| PC1    | JIN    | NixOS desktop — AMD Radeon R7 430                                                                  |
| PC2    | FENNEC | NixOS desktop — NVIDIA RTX 3080 (also drives TV via HDMI)                                          |
| PC3    | EDGE   | MacBook Pro 15.4" Mid 2018, Core i9 2.9 GHz, 32 GB, 1 TB, Space Grey, QWERTY (USB-C → DP into KVM) |
| PC4    | Work   | Work laptop                                                                                        |

## Per-host display wiring

### JIN (KVM PC1)

| GPU output | Connection        | Sink                      |
| ---------- | ----------------- | ------------------------- |
| DP-1       | KVM PC1 bottom DP | M1 (Gigabyte M27U)        |
| DP-2       | KVM PC1 top DP    | M2 (Dell P2425, portrait) |

BIOS POSTs on **M1** ✅

### FENNEC (KVM PC2)

| GPU output | Connection                        | Sink                      |
| ---------- | --------------------------------- | ------------------------- |
| DP-3       | RTX 3080 DP-3 → KVM PC2 bottom DP | M1 (Gigabyte M27U)        |
| DP-2       | KVM PC2 top DP                    | M2 (Dell P2425, portrait) |
| HDMI-A-1   | Long HDMI direct                  | TV (Samsung 55Q70R)       |

BIOS POSTs on **M1** ✅ — see [Resolution](#resolution--fennec-bios-posts-on-m1).

## Resolution — FENNEC BIOS POSTs on M1

On cold boot of FENNEC, the BIOS / GRUB splash now appears on M1 (main).
Previously it appeared on M2 (secondary, portrait). The fix was a one-time
physical rewire on the GPU side combined with a connector-name update in the
display profiles.

**Background — why this was hard to fix in software:**

- ASUS PRIME X570-PRO BIOS has no per-output POST display selector. The
  _Primary Display_ / _Initial Display Output_ options only choose between
  iGPU / dGPU / PCIe slots. With a 5900X (no iGPU) + single dGPU, those
  settings are inert.
- Consumer NVIDIA cards (RTX 3080) have no software- or BIOS-exposed POST
  display ordering. Order is hardcoded in the VBIOS, scanning physical
  connectors in a fixed sequence; first connector returning EDID wins.
- The KVM does **not** emulate EDID, so the GPU only sees an EDID on a DP
  input when (a) FENNEC is the active KVM input AND (b) the corresponding
  monitor is powered on (KVM passes HPD through from the real monitor).

### Boot-state test matrix

Preserved as evidence for the [NVIDIA POST display scan order](#nvidia-post-display-scan-order)
rule documented below. The matrix was recorded with M1 on DP-1, M2 on DP-2,
TV on HDMI-A-1 (the pre-fix wiring).

> **"powered" = display soft-power on / off via the monitor's own power
> button** (TV power button for the Samsung). Leave all DP and HDMI cables
> connected. When a monitor is powered off it drops HPD on the DP line, the
> KVM passes that through, and the GPU sees the input as disconnected (no
> EDID). Switching the monitor to a different input source while keeping it
> on does **not** drop HPD on most monitors and will not work for this test.

| #   | KVM active input | M1 powered | M2 powered | TV powered | Hypothesis                              | Observed                                    |
| --- | ---------------- | ---------- | ---------- | ---------- | --------------------------------------- | ------------------------------------------- |
| 1   | PC2 (FENNEC)     | on         | on         | off        | baseline — currently M2                 | **M2** (baseline)                           |
| 2   | PC2 (FENNEC)     | on         | **off**    | off        | M1 (M2 EDID absent)                     | **M1** ✅                                   |
| 3   | PC2 (FENNEC)     | **off**    | on         | off        | M2 (M1 EDID absent)                     | **M2**                                      |
| 4   | PC2 (FENNEC)     | on         | on         | **on**     | possibly TV (HDMI often wins on NVIDIA) | **M2** (TV not preferred)                   |
| 5   | **PC1 (JIN)**    | on         | on         | off        | nothing visible to FENNEC; TV if on     | **M1** (KVM passes EDID-state changes back) |

Follow-up cold boot with M1 moved to DP-3 (M2 still on DP-2, TV on HDMI-A-1):
BIOS POSTed on **M1** ✅ — confirming DP-3 wins over DP-2.

### Solution

1. **Physical rewire (one-time):** moved M1's cable from the RTX 3080's DP-1
   port to its DP-3 port. M2 stays on DP-2, TV stays on HDMI-A-1.
2. **Repo follow-up:** renamed every `DP-1` to `DP-3` in
   [hosts/FENNEC/home-manager/default.nix](hosts/FENNEC/home-manager/default.nix)
   so the display profiles and SDDM monitor layout target the new live DRM
   connector.
3. **Result:** BIOS, GRUB, and SDDM greeter all show on M1 deterministically.
   No monitor-power dance required.

## NVIDIA POST display scan order

The POST scan order on consumer NVIDIA cards is **highest-numbered DP first
→ descending DPs → HDMI last**. Properties of this rule:

- Hardcoded in VBIOS — not exposed in any motherboard BIOS option, NVIDIA
  control panel, or `nvidia-smi` flag.
- First connector returning EDID wins POST display.
- Practical consequence: to put BIOS / GRUB on a chosen monitor, plug it into
  the **highest-numbered DP** on the GPU.

Evidence from the [boot-state test matrix](#boot-state-test-matrix) above:

- DP-2 beat DP-1 when both had EDID (Test 1).
- DP-3 beat DP-2 when all three DPs had EDID (post-rewire confirmation).
- HDMI-A-1 lost to all DPs (Test 4 — TV on did not change POST display).

**Caveat:** scan order is per-card / per-VBIOS. Verified on **NVIDIA RTX 3080
(Ampere, GA102), PNY XLR8 Triple Fan**. Other Ampere SKUs are likely the same
but not guaranteed. Verify with a 2-monitor test before relying on this rule
on a different card.

## How SDDM monitor layout interacts with wiring

Two independent mechanisms put input/primary on M1 at the SDDM greeter. Both
are in play after the rewire + rename:

1. **GPU wiring** (deterministic, hardware-level): NVIDIA scan order picks
   the highest-numbered DP with EDID. With M1 on DP-3, KWin's auto-arrangement
   also tends to make the first-enumerated active output its primary — so
   even without our SDDM module, focus would land on M1.
2. **`custom.hmSddmMonitorLayout`** (declarative, software-level): emits
   `kwinoutputconfig.json` for the SDDM user with `priority: 0` on M1's
   connector and `disabledOutputs = [ "DP-2" "HDMI-A-1" ]`. KWin matches by
   `connectorName`. **Critical:** the connector names in the rendered file
   must match live DRM names — otherwise KWin silently falls back to
   auto-arrangement.

**Why the rename matters:** before the rename, the rendered file referenced
`DP-1` (which no longer exists post-rewire) — KWin was falling back to
auto-arrangement, and only the wiring was driving M1-focus behavior. After
the rename, both layers cooperate: wiring guarantees POST/primary on M1, the
SDDM module additionally blanks M2 and the TV at the greeter.

**How to tell which is doing what:**

- Greeter shows on M1 only (M2 + TV black) → our module is working.
- All three monitors show the greeter but cursor/focus is on M1 → only
  wiring is helping; check that connector names in
  `/var/lib/sddm/.config/kwinoutputconfig.json` match `ls /sys/class/drm/`.

## OS-level mitigation for KVM window shuffle

Because the KVM has no monitor emulation, switching PCs causes a DP
re-handshake and Plasma may reshuffle windows. Mitigations:

- **Plasma 6 (KDE):** _System Settings → Window Management → Window Behavior_
  — enable "Restore window positions when monitor returns".
- **macOS:** _System Settings → Desktop & Dock → Mission Control_ — uncheck
  "Automatically rearrange Spaces based on most recent use".
- **Windows 11:** _Settings → System → Display → Multiple Displays_ — enable
  "Remember windows locations based on monitor connection", uncheck "Minimize
  windows when a monitor is disconnected".
