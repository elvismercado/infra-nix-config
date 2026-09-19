# Gigabyte AORUS GeForce GTX 1060 6G 9Gbps (GV-N1060AORUS-6GD rev 2.0)
# GPU: GP106 (Pascal, 16 nm TSMC, CUDA Compute Capability 6.1)
# PCI ID: 10de:1c03
# Driver: nvidia (proprietary — open kernel modules do NOT support Pascal)
#
# Specifications (AORUS factory-overclocked):
#   - CUDA Cores: 1280, TMUs: 80, ROPs: 48
#   - Base Clock: 1607 MHz, Boost Clock: ~1835 MHz (OC mode)
#   - Memory: 6 GB GDDR5, 192-bit bus, 9 Gbps effective (216 GB/s bandwidth)
#   - TDP: 120 W, 1× 8-pin PCIe power connector
#   - PCIe 3.0 ×16
#
# Capabilities:
#   - Vulkan 1.3, OpenGL 4.6, DirectX 12 (feature level 12_1)
#   - NVENC Gen 6 (H.264 + HEVC encode)
#   - NVDEC Gen 3 (H.264, HEVC Main/Main10, VP9 hardware decode)
#   - Display outputs: 1× DVI-D, 3× HDMI 2.0b, 1× DisplayPort 1.4
#   - VR Ready
#
# Limitations:
#   - No ray-tracing cores (no RTX / hardware RT)
#   - No Tensor cores (no DLSS)
#   - No NVIDIA open kernel modules (Pascal is proprietary-only; hardware.nvidia.open must be false)
#   - No VRR on Wayland (requires Volta or newer GPU)
#   - No HDR output (Pascal hardware limitation)
#   - No 10-bit color output (Pascal hardware limitation)
#   - nvidia_drm.fbdev=1 required for Wayland on Linux 6.11+ (zen kernel)
#   - forceFullCompositionPipeline: X11-only, irrelevant on Wayland
#   - NVIDIA Game Ready driver support ended December 2025
#     (security updates continue until October 2028)
#   - SLI not supported on GTX 1060
#
# Use cases: 1080p gaming, video playback, general desktop, light compute (CUDA 6.1)

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
    custom.sysNixNvidiaGtx1060.enable = lib.mkEnableOption "NVIDIA GTX 1060 6GB (Pascal/GP106) graphics with proprietary driver and nvtop";
  };

  config = lib.mkIf config.custom.sysNixNvidiaGtx1060.enable {
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
      # Without this, powerManagement.enable dumps 6 GB VRAM to tmpfs on suspend,
      # overflowing RAM and causing a blank screen on resume.
      # Arch Linux sets this by default; NixOS does not.
      "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    ];
    boot.blacklistedKernelModules = [
      "nouveau"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];
    services.xserver.enable = false;

    hardware.enableAllFirmware = true;

    hardware.firmware = with pkgs; [
      linux-firmware # firmware files available at boot time (initrd stage)
    ];

    hardware.nvidia = {
      # Pascal (GP106) is NOT supported by the open-source kernel modules.
      # Open modules require Turing (GTX 16 / RTX 20 series) or newer.
      open = false;
      modesetting.enable = true; # DRM KMS — required for Wayland
      # forceFullCompositionPipeline: X11-only, irrelevant on Wayland.
      # Pascal does not support VRR on Wayland regardless. Intentionally disabled.
      # forceFullCompositionPipeline = false;
      nvidiaSettings = true; # GUI tool for display config, debugging
      powerManagement.enable = true; # Save/restore VRAM on suspend (NVreg_PreserveVideoMemoryAllocations=1)
    };

    hardware.graphics = {
      enable = true; # Mesa — provides OpenGL + Vulkan + OpenCL support
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
      # Point Vulkan loader to the NVIDIA ICD (ensures Vulkan apps use the GTX 1060)
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
    };

    # Diagnostic shell aliases moved to modules/home-manager/linux/aliases.nix (custom.hmAliasesNvidiaGpu)
  };
}

# Verification commands:
# nix-shell -p pciutils --run "lspci -nn | grep -i vga"          → should show 10de:1c03
# nvidia-smi                                                       → driver version + GPU info
# nix-shell -p vulkan-tools --run "vulkaninfo --summary"           → Vulkan 1.3 via NVIDIA
# nix-shell -p vulkan-tools --run "vulkaninfo | grep deviceName"   → GeForce GTX 1060
# nix-shell -p libva-utils --run "vainfo"                          → VA-API via nvidia-vaapi-driver
# nvtop                                                            → GPU utilisation monitor

# Known quirks & solutions:
#
# Quirk: "NVIDIA open kernel modules do not support Pascal"
#   → Expected — hardware.nvidia.open MUST be false for this GPU.
#     The open modules only support Turing (GTX 16 / RTX 20) and newer.
#
# Quirk: Game Ready drivers ended for Pascal (December 2025)
#   → NVIDIA continues security-only updates until October 2028.
#     If nvidiaPackages.stable drops Pascal support, pin to the last
#     compatible release via hardware.nvidia.package:
#       hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver { ... };
#     Check: https://www.nvidia.com/en-us/drivers/unix/
#
# Quirk: Graphical corruption or black screen on suspend/resume
#   → powerManagement.enable and NVreg_TemporaryFilePath are already set above.
#     If issues persist, verify NVreg_PreserveVideoMemoryAllocations=1 is active:
#       cat /sys/module/nvidia/parameters/NVreg_PreserveVideoMemoryAllocations
#
# Quirk: Screen tearing on Wayland/X11
#   → KDE Plasma: already uses VSync by default on Wayland.
#     forceFullCompositionPipeline is X11-only — do not enable on Wayland.
#
# Quirk: nouveau loads instead of nvidia
#   → Verify boot.blacklistedKernelModules contains "nouveau".
#     Check: cat /proc/modules | grep nouveau
#
# Quirk: No hardware video acceleration in browsers
#   → Firefox: set media.ffmpeg.vaapi.enabled = true in about:config.
#     nvidia-vaapi-driver provides VA-API via NVDEC.
