# Steam — Linux app façade (system-level, self-contained)
#
# Cross-layer module that owns the Linux Steam stack under one host-facing
# toggle (`custom.appSteam.enable`) shared with the darwin façade. Unlike
# the HM-based Linux façades (signal, libreoffice, brave …), Steam needs
# system-level config (programs.steam, GameMode, Gamescope, sysctls, udev
# rules), so this façade lives entirely at the system layer and owns
# everything directly — there is no separate `sysNix*` module behind it.
#
# Stack:
#   - programs.steam   — Steam itself with GE-Proton in extraCompatPackages,
#                        for broad game compatibility (community Proton
#                        builds with extra fixes; appears in Steam's
#                        per-game compatibility dropdown alongside official
#                        Proton versions).
#   - programs.gamemode — temporarily optimises CPU governor, GPU clocks,
#                        and process niceness while a game is running.
#                        Activated per-game via launch options.
#   - programs.gamescope — Valve's micro-compositor for resolution scaling,
#                        HDR, VRR, and frame limiting. Available as a tool
#                        for launch options.
#   - lutris            — open-source launcher for non-Steam games (Epic,
#                        GOG, Battle.net, standalone Windows installers).
#                        Manages Wine/Proton.
#   - dualsensectl      — CLI to control DualSense (PS5) lightbar, mic LED,
#                        battery status, and power off.
#   - 32-bit graphics   — required for Steam's FHS environment. Set via
#                        `lib.mkDefault` so GPU-specific modules (e.g.
#                        nvidia_rtx_3080.nix) can already declare it.
#   - vm.max_map_count  — SteamOS uses this for max game compatibility;
#                        some games crash or stutter at the default value.
#   - udev + uinput     — broader controller support outside Steam (PlayStation
#                        USB adapters, BigBigWon, third-party gamepads —
#                        used by emulators and Lutris).
#
# Steam launch options reference (set per-game in Properties → Launch Options):
#   gamemoderun %command%                       — GameMode performance tuning
#   mangohud %command%                          — FPS / performance overlay
#   gamemoderun mangohud %command%              — both at once
#   gamescope -- %command%                      — run through Gamescope
#   gamescope -W 1920 -H 1080 -f -- %command%   — Gamescope with resolution
#
# Gamescope session (Steam Deck-like boot-to-Steam) is not enabled by default.
# To enable, add to your host configuration:
#   programs.steam.gamescopeSession.enable = true;
#
# MangoHud is configured separately via home-manager (linux/gaming.nix).
#
# Usage:
#   imports = [ ../../../modules/apps/linux/steam.nix ];
#   custom.appSteam.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.appSteam;
in
{
  options.custom.appSteam.enable =
    lib.mkEnableOption "Steam with gaming tools (Proton, GameMode, Gamescope, Lutris, controller support)";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;

      # GE-Proton — community Proton builds with extra game fixes and patches.
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    # 32-bit graphics libraries — required for Steam's FHS environment.
    # Safe mkDefault: GPU-specific modules (e.g. nvidia_rtx_3080.nix) may
    # already set this; mkDefault avoids conflicts.
    hardware.graphics.enable32Bit = lib.mkDefault true;

    # SteamOS uses this value for maximum game compatibility.
    boot.kernel.sysctl."vm.max_map_count" = 2147483642;

    environment.systemPackages = with pkgs; [
      lutris
      dualsensectl
    ];

    # Broader udev rules for controllers outside Steam (emulators, Lutris).
    services.udev.packages = [ pkgs.game-devices-udev-rules ];
    hardware.uinput.enable = true;
  };
}
