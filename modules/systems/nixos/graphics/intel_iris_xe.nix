# Intel Iris Xe Graphics (Tiger Lake / 11th gen integrated GPU)
# GPU: Xe-LP (Gen 12.1)
# Driver: i915 (in-tree, no force_probe needed)
#
# Capabilities:
#   - OpenGL 4.6 (Iris via Mesa)
#   - Vulkan 1.3 (ANV via Mesa)
#   - VA-API hardware decode/encode: H.264, HEVC, VP9, AV1 decode (iHD)
#   - QSV / Intel VPL video encode (vpl-gpu-rt)
#   - Display: HDMI 2.0b, DisplayPort 1.4, eDP for built-in panel
#
# Limitations:
#   - No AV1 encode (decode only)
#   - Shares system RAM (no dedicated VRAM)
#
# Use cases: laptop iGPU — desktop / general, video playback, light
# 3D, hardware video decode/encode for media playback. Not suited for
# AAA gaming or heavy compute.
#
# Notes:
#   - Tiger Lake's i915 PCI IDs are in the default kernel probe list, so
#     we do NOT set i915.force_probe (unlike Arc A380 / DG2 which needs it).
#   - boot.kernelPackages is intentionally NOT pinned here — the latest
#     stable kernel from nixpkgs is fine for Tiger Lake. Per-host profiles
#     can override if needed.
#   - intel-compute-runtime (NEO / OpenCL) is omitted — niche workload on
#     a non-technical user's laptop. Add if needed.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/graphics/intel_iris_xe.nix ];
#   custom.sysNixIntelIrisXe.enable = true;

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
    custom.sysNixIntelIrisXe.enable = lib.mkEnableOption "Intel Iris Xe Graphics (Tiger Lake / Gen 12.1) with Mesa, VA-API (iHD) and intel-nvtop";
  };

  config = lib.mkIf config.custom.sysNixIntelIrisXe.enable {
    custom.sysNixNvtopIntel.enable = true;

    boot.initrd.kernelModules = [ "i915" ]; # early KMS — clean transition from firmware to kernel framebuffer

    hardware.enableRedistributableFirmware = true; # Intel GuC/HuC firmware blobs

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa # OpenGL (Iris) + Vulkan (ANV)
        intel-media-driver # VA-API hardware video decode/encode (iHD)
        vpl-gpu-rt # Intel VPL runtime (QSV) for Tiger Lake+
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        intel-media-driver
      ];
    };

    environment.sessionVariables = {
      # Force VA-API to use the Intel iHD driver (hardware video decode/encode).
      LIBVA_DRIVER_NAME = "iHD";

      # Force Firefox / Mozilla apps to use the Wayland backend (KDE Plasma 6
      # default session is Wayland).
      MOZ_ENABLE_WAYLAND = "1";
    };
  };
}

# Verification commands:
# nix-shell -p pciutils --run "lspci -nn | grep -i vga"
# sudo dmesg | grep -i i915
# nix-shell -p glxinfo --run "glxinfo | grep 'OpenGL renderer'"
# nix-shell -p vulkan-tools --run "vulkaninfo --summary"
# nix-shell -p libva-utils --run "vainfo"  # expect iHD driver, Tiger Lake codecs
