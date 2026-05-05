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

| GPU output | Connection        | Sink                      |
| ---------- | ----------------- | ------------------------- |
| DP-1       | KVM PC2 bottom DP | M1 (Gigabyte M27U)        |
| DP-2       | KVM PC2 top DP    | M2 (Dell P2425, portrait) |
| HDMI-A-1   | Long HDMI direct  | TV (Samsung 55Q70R)       |

BIOS POSTs on **M2** ⚠️ by default — see [Open issue](#open-issue--fennec-bios-posts-on-m2). Workaround: power M2 off before cold boot.

## Open issue — FENNEC BIOS POSTs on M2

On cold boot of FENNEC, the BIOS / GRUB splash appears on M2 (secondary,
portrait) instead of M1 (main).

**Why this is hard to fix:**

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
- Implication: powering off / disconnecting one monitor at boot suppresses its
  EDID at the GPU and can change which connector POSTs.

### Boot-state test matrix

Cold-boot FENNEC, varying only the listed input. Recorded which display
showed the BIOS splash.

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

### Workaround

**Power M2 off before cold-booting FENNEC; power it back on after the GRUB
menu / SDDM greeter appears on M1.** Test 2 confirms this is deterministic.

Notes from the matrix:

- **Tests 2 + 3** (symmetric) show NVIDIA picks the DP connector that has an
  EDID; with both EDIDs present, it prefers DP-2 (M2).
- **Test 4** shows HDMI-A-1 (TV) is **not** preferred over DP — leaving the
  TV on does not change POST display.
- **Tests 1 vs 5** (same monitor power, only KVM input differs) show the KVM
  is propagating EDID-state changes back to FENNEC even when switched to
  another PC. Not actionable for daily use, but explains why POST display
  felt non-deterministic before this matrix.

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
