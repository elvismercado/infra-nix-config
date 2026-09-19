# Intel Arc A380 (ASRock Challenger ITX / reference)
# GPU: ACM-G11 (Alchemist / Xe-HPG / DG2)
# PCI ID: 8086:56a5
# Driver: i915 (with force_probe)
#
# Capabilities:
#   - OpenGL 4.6 (Iris via Mesa)
#   - Vulkan 1.3 (ANV via Mesa)
#   - VA-API hardware decode/encode: H.264, HEVC, VP9, AV1 (iHD)
#   - QSV / Intel VPL video encode (vpl-gpu-rt)
#   - OpenCL 3.0 (NEO / intel-compute-runtime)
#   - Display: HDMI 2.0b, 3× DisplayPort 2.0
#   - VRR: VESA AdaptiveSync via DisplayPort 2.0 (auto-enabled by KDE on DG2)
#         KDE Plasma 6: System Settings → Display → Compositor → Adaptive Sync
#   - HDR: experimental on Gen 9+ (KDE Plasma 6 toggle in Display settings)
#   - 10-bit color output (DP), 4K@120Hz+ (DP 2.0)
#
# Limitations:
#   - Requires ReBAR enabled in BIOS (bus errors without it)
#   - Requires force_probe kernel param (not in default i915 probe list on stable)
#   - GuC/HuC firmware must load successfully for full performance
#   - No AV1 encode (decode only; encode requires Arc A580+)
#   - HDMI limited to 2.0b (no VRR over HDMI; use DisplayPort for VRR)
#
# Use cases: desktop / general, video playback, light gaming, hardware transcode
#
# BIOS prerequisites:
#   - Disable Compatibility Support Module (CMS) / Legacy Mode
#   - Enable UEFI boot
#   - Enable Above 4G Decoding
#   - Enable Re-Size BAR (ReBAR) support
#     Without ReBAR, programs crash with "bus error" (e.g. vainfo, mpv, falkon)

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./utilities/nvtop-intel.nix
  ];

  options = {
    custom.sysNixIntelArcIntelDriver.enable = lib.mkEnableOption "Intel Arc A380 graphics with the Intel driver and intel-nvtop";
  };

  config = lib.mkIf config.custom.sysNixIntelArcIntelDriver.enable {
    custom.sysNixNvtopIntel.enable = true;

    boot.initrd.kernelModules = [ "i915" ]; # Early KMS start
    boot.kernelParams = [
      "i915.force_probe=56a5" # force probe Arc A380 (PCI ID 56a5)
      "i915.enable_guc=3" # enable GuC submission + HuC firmware loading # https://wiki.archlinux.org/title/intel_graphics
    ];

    # Unlock GPU performance counters for all users (negligible security risk)
    # Without this, Steam warns and some apps/games have reduced performance
    # https://github.com/NixOS/nixos-hardware/issues/1246
    boot.kernel.sysctl."dev.i915.perf_stream_paranoid" = 0;

    hardware.enableAllFirmware = true; # includes linux-firmware (GuC/HuC blobs)

    # DDC/CI monitor control (brightness, contrast, input switching via software)
    # Requires i2c-dev kernel module; harmless if monitors don't support DDC/CI
    boot.kernelModules = [ "i2c-dev" ];

    services.xserver.videoDrivers = lib.mkDefault [ "modesetting" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa # OpenGL (Iris) + Vulkan (ANV) - ANV is built into Mesa
        intel-media-driver # VA-API hardware video decode/encode (iHD)
        vpl-gpu-rt # Intel VPL runtime (QSV) for Tiger Lake+ / Arc
        intel-compute-runtime # OpenCL (NEO)
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa # 32-bit OpenGL + Vulkan (Wine/Proton games)
        intel-media-driver
      ];
    };

    environment.sessionVariables = {
      # Force VA-API to use the Intel iHD driver (hardware video decode/encode)
      LIBVA_DRIVER_NAME = "iHD";

      # Qt Quick rendering via RHI (modern Vulkan-capable backend)
      QT_QUICK_BACKEND = "rhi";

      # SDL_VIDEODRIVER: not set — modern SDL2/SDL3 auto-detect Wayland.
      # Forcing "wayland" breaks Easy Anti-Cheat games under Proton (Elden Ring, etc.)
      # SDL_VIDEODRIVER = "wayland";

      # Force Firefox/Mozilla apps to use the Wayland backend
      MOZ_ENABLE_WAYLAND = "1";
    };

    environment.systemPackages = with pkgs; [
      ddcutil # DDC/CI monitor control (brightness, contrast via CLI)
    ];
  };
}

# Verification commands:
# nix-shell -p pciutils --run "lspci -nn | grep -i vga"
# sudo dmesg | grep -i -e 'i915' -e 'guc' -e 'huc'
# nix-shell -p glxinfo --run "glxinfo | grep 'OpenGL renderer'"
# nix-shell -p vulkan-tools --run "vulkaninfo --summary"
# nix-shell -p vulkan-tools --run "vulkaninfo | grep deviceName"
# nix-shell -p libva-utils --run "vainfo"
# nix-shell -p clinfo --run "clinfo"
# cat /proc/sys/dev/i915/perf_stream_paranoid  # expect 0

# Known quirks & solutions:
#
# Quirk: "bus error" running vainfo, mpv, etc.
#   → Enable Resizable BAR (ReBAR) in BIOS. Some motherboards require UEFI-only mode.
#
# Quirk: Corrupted or frozen graphics in some apps (random colors, blurriness)
#   → Run the app with OpenGL instead of Vulkan. Some Arc configs hit Vulkan bugs.
#     Per-app: MESA_LOADER_DRIVER_OVERRIDE=iris <app>
#
# Quirk: Washed-out / desaturated colors on HDMI
#   → Intel HDMI defaults to "Limited" Broadcast RGB (16-235) instead of "Full" (0-255).
#     Fix in KDE: System Settings → Display → select HDMI output → RGB Range → Full.
#     Or via CLI: nix-shell -p xorg.xrandr --run 'xrandr --output HDMI-A-1 --set "Broadcast RGB" "Full"'
#     Or via drm_info: nix-shell -p libdrm --run 'proptest -M i915 <connector-id> connector "Broadcast RGB" 2'
#
# Quirk: Screen flickering (Panel Self Refresh)
#   → Add "i915.enable_psr=0" to boot.kernelParams
#
# Quirk: xe driver alternative (experimental, kernel 6.8+)
#   → Replace i915 params with: "i915.force_probe=!56a5" "xe.force_probe=56a5"
#     Not yet recommended for stability.
