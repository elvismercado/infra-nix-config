# Lenovo MSI RTX 3070 8G LHR (MSI@RTX3070@8G/D6/3DP/H/LHR)
# GPU: GA104-302 (Ampere, Samsung 8 nm 8N, CUDA Compute Capability 8.6, LHR)
# PCI ID: 10de:2488 (LHR revision)
# Driver: nvidia (open kernel modules)
#
# Specifications (reference clocks — OEM may vary slightly):
#   - CUDA Cores: 5888, TMUs: 184, ROPs: 96
#   - RT Cores: 46 (2nd generation)
#   - Tensor Cores: 184 (3rd generation)
#   - Base Clock: 1500 MHz, Boost Clock: 1725 MHz
#   - Memory: 8 GB GDDR6, 256-bit bus, 14 Gbps (448 GB/s bandwidth)
#   - TDP: 220 W, PCIe 4.0 ×16
#
# Capabilities:
#   - Vulkan 1.4, OpenGL 4.6, DirectX 12 Ultimate (feature level 12_2)
#   - Hardware ray tracing (2nd gen RT cores)
#   - DLSS (3rd gen Tensor cores)
#   - NVENC Gen 7 (H.264 + HEVC encode)
#   - NVDEC Gen 5 (H.264, HEVC, VP9, AV1 hardware decode)
#   - Display outputs: 3× DisplayPort 1.4a, 1× HDMI 2.1
#   - CUDA Compute 8.6, VR Ready
#   - VRR: G-Sync + G-Sync Compatible (Wayland supported since Volta+)
#         KDE Plasma 6: System Settings → Display → Compositor → Adaptive Sync
#   - HDR: supported (Plasma 6 toggle in Display settings)
#   - 10-bit color, 4K@120Hz (DP 1.4a)
#
# Limitations:
#   - nvidia_drm.fbdev=1 required for Wayland on Linux 6.11+ (zen kernel)
#   - Open kernel modules require GSP firmware (NVreg_EnableGpuFirmware=0 is incompatible)
#   - Early KMS (nvidia in initrd) + hibernation: initramfs cannot access
#     NVreg_TemporaryFilePath, so hibernate (S4) may fail; suspend (S3) works fine
#   - forceFullCompositionPipeline: X11-only, irrelevant on Wayland, breaks VRR
#   - LHR (Lite Hash Rate) — crypto mining limiter was present in early drivers;
#     fully removed since driver 522.25 (October 2022). No impact on any workload.
#   - OEM card (Lenovo/MSI) — may lack retail-style RGB or fan headers
#
# Use cases: 1440p / 4K gaming, ray tracing, DLSS, video editing, compute (CUDA 8.6)

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
    custom.sysNixNvidiaRtx3070Lhr.enable = lib.mkEnableOption "NVIDIA RTX 3070 LHR (Ampere/GA104) graphics with proprietary driver and nvtop";
  };

  config = lib.mkIf config.custom.sysNixNvidiaRtx3070Lhr.enable {
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
      # Without this, powerManagement.enable dumps 8 GB VRAM to tmpfs on suspend,
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
      linux-firmware # firmware files available at boot time (initrd stage)
    ];

    hardware.nvidia = {
      # Open kernel modules — recommended by NVIDIA for Turing+ (RTX 20-series onward),
      # required for Blackwell+. Desktop Ampere (GA104) is fully supported and stable.
      # To revert: set open = false and remove nvidia_drm.fbdev=1 from kernelParams.
      open = true;
      modesetting.enable = true; # DRM KMS — required for Wayland
      # forceFullCompositionPipeline: X11-only, irrelevant on Wayland.
      # Enabling it breaks VRR (G-Sync / Adaptive Sync). Intentionally disabled.
      # forceFullCompositionPipeline = false;
      nvidiaSettings = true; # GUI tool for G-Sync verification, display config, debugging
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
      # Point Vulkan loader to the NVIDIA ICD (ensures Vulkan apps use the RTX 3070)
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
# nix-shell -p pciutils --run "lspci -nn | grep -i vga"          → should show 10de:2488
# nvidia-smi                                                       → driver version + GPU info
# nix-shell -p vulkan-tools --run "vulkaninfo --summary"           → Vulkan 1.4 via NVIDIA
# nix-shell -p vulkan-tools --run "vulkaninfo | grep deviceName"   → GeForce RTX 3070
# nix-shell -p libva-utils --run "vainfo"                          → VA-API via nvidia-vaapi-driver
# nvtop                                                            → GPU utilisation monitor

# Known quirks & solutions:
#
# Quirk: Graphical corruption or black screen on suspend/resume
#   → powerManagement.enable and NVreg_TemporaryFilePath are already set above.
#     If issues persist, verify NVreg_PreserveVideoMemoryAllocations=1 is active:
#       cat /sys/module/nvidia/parameters/NVreg_PreserveVideoMemoryAllocations
#
# Quirk: Screen tearing on Wayland/X11
#   → KDE Plasma: already uses VSync by default on Wayland.
#     forceFullCompositionPipeline is X11-only and breaks VRR — do not enable on Wayland.
#
# Quirk: nouveau loads instead of nvidia
#   → Verify boot.blacklistedKernelModules contains "nouveau".
#     Check: cat /proc/modules | grep nouveau
#
# Quirk: No hardware video acceleration in browsers
#   → Firefox: set media.ffmpeg.vaapi.enabled = true in about:config.
#     nvidia-vaapi-driver provides VA-API via NVDEC.
#
# Quirk: Need to revert to proprietary kernel modules?
#   → Set hardware.nvidia.open = false; and remove nvidia_drm.fbdev=1 from kernelParams.
#     Do NOT add NVreg_EnableGpuFirmware=0 while open = true (they are incompatible).
#
# Quirk: LHR (Lite Hash Rate) — does it affect me?
#   → No. The LHR limiter was fully removed in driver 522.25 (October 2022).
#     All current drivers treat LHR and non-LHR cards identically.
