# NVIDIA GeForce RTX 3080 (Founders Edition / reference)
# GPU: GA102 (Ampere)
# PCI ID: 10de:2206
# Driver: nvidia (open kernel modules)
#
# Capabilities:
#   - OpenGL 4.6 + Vulkan 1.3 (NVIDIA proprietary userspace)
#   - VA-API hardware decode via nvidia-vaapi-driver (H.264, HEVC, VP9, AV1)
#   - NVENC hardware encode (H.264, HEVC, AV1)
#   - CUDA, OptiX, OpenCL
#   - VRR: G-Sync + G-Sync Compatible (Wayland supported since Volta+)
#         KDE Plasma 6: System Settings → Display → Compositor → Adaptive Sync
#   - HDR: supported (Plasma 6 toggle in Display settings)
#   - Display: HDMI 2.1, 3× DisplayPort 1.4a
#   - 10-bit color, 4K@120Hz, 8K@60Hz (DP 1.4 DSC)
#
# Limitations:
#   - nvidia_drm.fbdev=1 required for Wayland on Linux 6.11+
#   - Open kernel modules require GSP firmware (NVreg_EnableGpuFirmware=0 is incompatible)
#   - Early KMS (nvidia in initrd) + hibernation: initramfs cannot access
#     NVreg_TemporaryFilePath, so hibernate (S4) may fail; suspend (S3) works fine
#   - forceFullCompositionPipeline: X11-only, irrelevant on Wayland, breaks VRR
#
# Use cases: desktop / gaming, video playback, GPU compute, hardware transcode

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./utilities/nvtop-nvidia.nix
  ];

  options = {
    custom.sysNixNvidiaRtx3080.enable = lib.mkEnableOption "NVIDIA RTX 3080 graphics with proprietary driver and nvtop";
  };

  config = lib.mkIf config.custom.sysNixNvidiaRtx3080.enable {
    custom.sysNixNvtopNvidia.enable = true;

    boot.initrd.kernelModules = [
      "nvidia"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia_drm"
    ]; # Early KMS start
    boot.kernelParams = [
      # Required for Wayland on Linux 6.11+.
      # NixOS has no hardware.nvidia.fbdev option — must be set manually.
      # Without this, KDE Plasma / Wayland may fail to present frames or black-screen.
      "nvidia_drm.fbdev=1"

      # Redirect VRAM save location from /tmp (tmpfs on NixOS) to /var/tmp (on-disk).
      # Without this, powerManagement.enable dumps 10 GB VRAM to tmpfs on suspend,
      # overflowing RAM and causing a blank screen on resume.
      # Arch Linux sets this by default; NixOS does not.
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    ];

    # WARNING: "nvidia.NVreg_EnableGpuFirmware=0" is INCOMPATIBLE with open = true.
    # The open kernel modules require GSP firmware. Only use NVreg_EnableGpuFirmware=0
    # if you switch back to open = false (proprietary modules).
    # See: https://github.com/NixOS/nixpkgs/issues/325378
    boot.blacklistedKernelModules = [
      "nouveau"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];
    services.xserver.enable = false;

    hardware.enableAllFirmware = true;

    hardware.firmware = with pkgs; [
      linux-firmware # firmware files available at boot time (initrd stage).
    ];

    hardware.nvidia = {
      # Open kernel modules — recommended by NVIDIA for Turing+ (RTX 20-series onward),
      # required for Blackwell+. Desktop Ampere (GA102) is fully supported and stable.
      # Laptop Ampere may have GSP-related crashes; desktop is unaffected.
      # To revert: set open = false and remove nvidia_drm.fbdev=1 from kernelParams.
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (oldAttrs: {
        passthru = oldAttrs.passthru // {
          open = oldAttrs.passthru.open.overrideAttrs (openAttrs: {
            patches = (openAttrs.patches or [ ]) ++ [ ./nvidia-open-strncpy.patch ];
          });
        };
      });
      modesetting.enable = true; # DRM KMS — required for Wayland
      # forceFullCompositionPipeline: X11-only, irrelevant on Wayland.
      # Enabling it breaks VRR (G-Sync / Adaptive Sync). Intentionally disabled.
      # forceFullCompositionPipeline = false;
      nvidiaSettings = true; # GUI tool for G-Sync verification, display config, debugging
      powerManagement.enable = true; # Save/restore VRAM on suspend (NVreg_PreserveVideoMemoryAllocations=1)
    };

    hardware.graphics = {
      enable = true; # Mesa # Open source 3D graphics library # provides OpenGL + Vilkan +OpenCL?
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        nvidia-vaapi-driver
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        nvidia-vaapi-driver
      ];
    };

    environment.sessionVariables = {
      # https://nixos.org/manual/nixos/stable/#sec-gpu-accel-opencl
      # OCL_ICD_VENDORS = "`nix-build '<nixpkgs>' --no-out-link -A rocmPackages.clr.icd`/etc/OpenCL/vendors/"; # remove if set by hardware.graphics.extraPackages

      # Point Vulkan loader to the NVIDIA ICD (ensures Vulkan apps use the RTX3080)
      # VK_ICD_FILENAMES = "`nix-build '<nixpkgs>' --no-out-link -A amdvlk`/share/vulkan/icd.d/amd_icd64.json";
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";

      # Qt Quick rendering via RHI — picks Vulkan or falls back to OpenGL,
      # avoiding legacy scenegraph paths. Without this, KDE Plasma 6 may fail
      # with "Could not load QML component".
      QT_QUICK_BACKEND = "rhi";

      # SDL_VIDEODRIVER: not set — modern SDL2/SDL3 auto-detect Wayland.
      # Forcing "wayland" breaks Easy Anti-Cheat games under Proton (Elden Ring, etc.)
      # SDL_VIDEODRIVER = "wayland";

      # Force Firefox (and other Mozilla apps) to use the Wayland backend
      MOZ_ENABLE_WAYLAND = "1";

      # Ensures Wine/Proton apps pick the NVIDIA Vulkan driver (avoids fallback to DZN)
      # WINE_VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
    };

    # Diagnostic shell aliases moved to modules/home-manager/linux/aliases.nix (custom.hmAliasesNvidiaGpu)
  };
}
