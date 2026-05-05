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

BIOS POSTs on **M2** ⚠️ — see [Open issue](#open-issue--fennec-bios-posts-on-m2).

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

### Boot-state test matrix (to be filled in)

Cold-boot FENNEC five times, varying only the listed input. Record which
display shows the BIOS splash:

| #   | KVM active input | M1 powered | M2 powered | TV powered | Hypothesis                              | Observed |
| --- | ---------------- | ---------- | ---------- | ---------- | --------------------------------------- | -------- |
| 1   | PC2 (FENNEC)     | on         | on         | off        | baseline — currently M2                 |          |
| 2   | PC2 (FENNEC)     | on         | **off**    | off        | M1 (M2 EDID absent)                     |          |
| 3   | PC2 (FENNEC)     | **off**    | on         | off        | M2 (M1 EDID absent)                     |          |
| 4   | PC2 (FENNEC)     | on         | on         | **on**     | possibly TV (HDMI often wins on NVIDIA) |          |
| 5   | **PC1 (JIN)**    | on         | on         | off        | nothing visible to FENNEC; TV if on     |          |

**Interpretation:**

- If Test 2 → M1: adopt habit "leave M2 powered off until past POST"; document
  here as the workaround.
- If Test 2 still shows M2: KVM presents EDIDs in fixed order regardless of
  monitor power. Non-physical fixes are exhausted; cable-swap at the GPU
  bracket (swap which physical DP port goes to bottom vs top) becomes the only
  remaining option. Move to [TODO.md](TODO.md) backlog.

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
