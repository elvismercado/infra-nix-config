# Linux-only shell aliases
#
# Provides the `postinstall` alias, NixOS switch/rebuild aliases
# (`switch`, `switchverbose`, `switchbuild`, `switchtest`, `switchhealth`, `switchhelp`),
# `nixdiag` boot diagnostics, and optional AMD CPU / NVIDIA GPU diagnostic aliases.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/aliases.nix ];
#   custom.hmLinuxAliases.enable = true;
#   custom.hmAliasesAmdCpu.enable = true;     # optional
#   custom.hmAliasesNvidiaGpu.enable = true;   # optional

{
  config,
  lib,
  userSettings,
  ...
}:

{
  options = {
    custom.hmLinuxAliases.enable = lib.mkEnableOption "Linux/NixOS shell aliases (postinstall, switch/rebuild, nixdiag)";
    custom.hmAliasesAmdCpu.enable = lib.mkEnableOption "AMD CPU diagnostic shell aliases";
    custom.hmAliasesNvidiaGpu.enable = lib.mkEnableOption "NVIDIA GPU diagnostic shell aliases";
  };

  config = lib.mkMerge [
    (lib.mkIf config.custom.hmLinuxAliases.enable {
      home.shellAliases = {
        postinstall = "bash ${config.home.homeDirectory}/${userSettings.repoPath}/scripts/nixos/postinstall.sh";
        switch = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && sudo nixos-rebuild switch --flake path:.#${userSettings.hostname}";
        switchverbose = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && sudo nixos-rebuild switch --flake path:.#${userSettings.hostname} --show-trace --print-build-logs -L -v";
        switchbuild = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && nixos-rebuild build --flake path:.#${userSettings.hostname}";
        switchtest = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && sudo nixos-rebuild dry-activate --flake path:.#${userSettings.hostname}";
        switchhealth = "{ echo '=== Failed units ==='; systemctl --failed; echo '=== Boot errors ==='; journalctl -b -p err --no-pager; echo '=== Boot warnings ==='; journalctl -b -p warning --no-pager; echo '=== Kernel hardware issues ==='; sudo dmesg --level=err,warn; echo '=== OOM events ==='; journalctl -b --no-pager | grep -i 'out of memory\|oom-kill\|killed process' || echo 'None'; echo '=== NVIDIA GPU ==='; nvidia-smi 2>/dev/null || echo 'nvidia-smi not available'; echo '=== Disk usage ==='; df -h / /home /boot; echo '=== Nix store size ==='; du -sh /nix/store 2>/dev/null; echo '=== NixOS generation ==='; nixos-rebuild list-generations --no-build-nix 2>/dev/null | tail -5; } > /tmp/health.txt 2>&1 && echo \"Saved to /tmp/health.txt ($(wc -l < /tmp/health.txt) lines)\"";
        switchhelp = "echo -e '\n  switch        — Rebuild and activate system config\n                  sudo nixos-rebuild switch --flake path:.#${userSettings.hostname}\n  switchverbose — Same as switch, with full build logs + eval trace\n                  sudo nixos-rebuild switch --flake path:.#${userSettings.hostname} --show-trace --print-build-logs -L -v\n  switchbuild   — Build config without activating\n                  nixos-rebuild build --flake path:.#${userSettings.hostname}\n  switchtest    — Test build (dry-activate)\n                  sudo nixos-rebuild dry-activate --flake path:.#${userSettings.hostname}\n  switchcheck   — Validate flake\n                  nix flake check\n  switchupdate  — Update flake inputs\n                  nix flake update\n  switchhealth  — Save system health report to /tmp/health.txt\n  switchcd      — cd to nix-config repo\n  switchhelp    — Show this help\n'";
        nixdiag = "journalctl -b -o short-monotonic > /tmp/_bootlog.txt; cat /proc/cmdline > /tmp/_bootparams.txt; journalctl -b | grep -i plymouth > /tmp/_plymouth.txt; sudo dmesg | grep -iE 'drm|amdgpu|fbcon|console' > /tmp/_drm_display_output_events.txt; journalctl -b | grep -i kscreen > /tmp/_kscreen.txt; journalctl -b -u display-manager | grep -iE 'kscreen|output|priority|primary' > /tmp/_display-manager.txt; cat /tmp/_bootlog.txt /tmp/_bootparams.txt /tmp/_plymouth.txt /tmp/_drm_display_output_events.txt /tmp/_kscreen.txt /tmp/_display-manager.txt > /tmp/_results.txt; echo 'Diagnostics saved to /tmp/_results.txt'";
      };
    })

    # AMD CPU diagnostic aliases (moved from modules/systems/nixos/cpu/amd.nix)
    (lib.mkIf config.custom.hmAliasesAmdCpu.enable {
      home.shellAliases = {
        amdmicrocode = "cat /proc/cpuinfo | grep microcode | uniq";
        sevcpu = "egrep -o 'sev|sev_es|sev_snp' /proc/cpuinfo | sort | uniq";
        sevkernel = "sudo dmesg | grep -i sev";
        sev = "ls -l /dev/sev";
        sevguest = "ls -l /dev/sev-guest";
        checkamdcpusupport = "amdmicrocode; sevcpu; sevkernel; sev; sevguest;";
      };
    })

    # NVIDIA GPU diagnostic aliases (moved from modules/systems/nixos/graphics/nvidia_rtx_3080.nix)
    (lib.mkIf config.custom.hmAliasesNvidiaGpu.enable {
      home.shellAliases = {
        gpuinfo = "nix-shell -p pciutils --run 'lspci -nn |grep -i vga'";

        openglinfo = "nix-shell -p glxinfo --run glxinfo |grep 'OpenGL renderer'";

        vlkinstalleddrivers = "echo '# start vlkinstalleddrivers start' && ls -alF /run/opengl-driver/share/vulkan/icd.d/ && echo '# end vlkinstalleddrivers end' && echo";
        vlkinfo = "nix-shell -p vulkan-tools --run 'vulkaninfo |grep deviceName'";
        vlkinfosummary = "nix-shell -p vulkan-tools --run 'vulkaninfo --summary'";
        vlkcube = "nix-shell -p vulkan-tools --run vkcube";
        checkallvulkan = "vlkinstalleddrivers; vlkinfo; vlkinfosummary;";

        openclinfo = "nix-shell -p clinfo --run 'clinfo | head -n3'";

        vaapiinfo = "nix-shell -p libva-utils --run vainfo";
        vdpauinfo = "nix-shell -p vdpauinfo --run vdpauinfo";

        checkallgpufeatures = "gpuinfo; openglinfo; openclinfo; vaapiinfo; vdpauinfo;";
      };
    })
  ];
}
