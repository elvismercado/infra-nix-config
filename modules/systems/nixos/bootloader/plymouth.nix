# Plymouth — boot splash screen between GRUB and the login screen
# https://wiki.archlinux.org/title/Plymouth
#
# Base module — enables Plymouth, systemd-based initrd, and silent boot.
# Does NOT select a theme. Import one of the plymouth-theme-*.nix files
# alongside this module to choose a theme. Without a theme file, Plymouth
# falls back to the default "bgrt" theme (UEFI vendor logo + spinner).
#
# Also enables:
#   - systemd-based initrd  — required for a flicker-free GRUB → Plymouth → login screen
#     transition. The legacy script-based initrd works but causes brief flickers.
#   - Silent boot params    — suppress kernel/systemd messages so only the
#     Plymouth animation is visible during boot.
#   - Boot log suppression  — disables Plymouth's own /var/log/boot.log via
#     plymouth.nolog (also disables console redirection).
#
# Kernel parameters set by this module:
#   quiet                      — suppress most kernel boot messages
#   splash                     — (auto-added by NixOS when Plymouth is enabled)
#   loglevel=3                 — only show kernel errors
#   rd.udev.log_level=3        — suppress udev messages in initrd
#   systemd.show_status=auto   — hide successful status lines, still show errors
#   vt.global_cursor_default=0 — hide blinking cursor during boot
#   logo.nologo                — suppress NixOS/Tux framebuffer logo
#   fbcon=vc:2-6               — restrict fbcon to VT2–6, preventing console flash on VT1
#   plymouth.nolog             — disable Plymouth boot log & console redirection
#
# Optional kernel parameters (controlled by options):
#   plymouth.use-simpledrm=0   — disable SimpleDRM (useSimpleDrm = false)
#   plymouth.debug             — write debug log to /var/log/plymouth-debug.log (debug = true)
#
# Emergency: if Plymouth breaks boot, add these to your bootloader
# kernel command line (press 'e' in GRUB or edit systemd-boot entry):
#   plymouth.enable=0
# This bypasses Plymouth entirely without changing your NixOS config.
#
# Usage:
#   imports = [
#     ../../../modules/systems/nixos/bootloader/plymouth.nix
#     ../../../modules/systems/nixos/bootloader/plymouth-theme-adi1090x.nix
#   ];
#   custom.sysNixPlymouth.enable = true;
#   custom.sysNixPlymouthThemeAdi1090x.enable = true;
#   custom.sysNixPlymouthThemeAdi1090x.theme = "angular_alt";
#
#   # Optional: disable secondary monitors during boot splash (multi-monitor setups)
#   custom.sysNixPlymouth.bootDisabledOutputs = [ "DP-2" ];  # auto-adds video=DP-2:d kernel param
#
#   # Optional: additional kernel video= params for pinning modes (rarely needed)
#   custom.sysNixPlymouth.bootVideoParams = [
#     "video=DP-1:2560x1440@100"   # primary — pin to a specific mode
#   ];
#
#   # Optional: HiDPI scaling (integer factor, e.g. 2 for 4K displays)
#   custom.sysNixPlymouth.deviceScale = 2;
#
#   # Optional: ensure full animation plays on fast-booting systems (seconds)
#   custom.sysNixPlymouth.minAnimationDuration = 5;
#
#   # Optional: ensure shutdown/reboot splash is visible (seconds)
#   custom.sysNixPlymouth.minShutdownDuration = 2;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    custom.sysNixPlymouth.enable = lib.mkEnableOption "Plymouth boot splash with silent boot and systemd initrd";

    custom.sysNixPlymouth.bootVideoParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Additional kernel video= parameters for early-boot display control.
        Use these to pin specific monitor modes during boot. Normally not
        needed — bootDisabledOutputs automatically adds video=<connector>:d
        for disabled outputs.

        Example:
          "video=DP-1:2560x1440@100"   — force DP-1 to 1440p 100 Hz
      '';
    };

    custom.sysNixPlymouth.bootDisabledOutputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        DRM connector names to disable during boot. Automatically adds
        video=<connector>:d kernel parameters so these outputs are off
        during GRUB and Plymouth.

        A oneshot systemd service runs before display-manager.service to
        re-enable these outputs (writes "detect" to sysfs), so the
        display manager sees all monitors.

        Example: [ "DP-2" ]
      '';
    };

    custom.sysNixPlymouth.deviceScale = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Integer scaling factor for HiDPI displays. Plymouth renders at 1x
        by default, which looks tiny on 4K screens. Set to 2 for 4K/Retina
        displays (only integer values are supported by Plymouth).
      '';
    };

    custom.sysNixPlymouth.useSimpleDrm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to use SimpleDRM for early-boot splash on UEFI systems.
        SimpleDRM displays the splash on the EFI framebuffer before the
        real GPU driver loads, eliminating flicker on fast-booting machines.

        Disable this (set to false) if:
          - Secondary monitors don't display during boot (docked laptops)
          - LUKS password prompt appears on the wrong screen
          - You experience issues with AMD GPUs during early boot
      '';
    };

    custom.sysNixPlymouth.minAnimationDuration = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Minimum time (in seconds) the Plymouth animation should be visible.
        On fast-booting systems (NVMe + modern CPU), Plymouth may only
        flash for a fraction of a second. This adds an ExecStartPre sleep
        to plymouth-quit.service, delaying Plymouth's exit until the
        specified duration has elapsed.

        Note: the sleep runs as a pre-start step of plymouth-quit, so it
        delays Plymouth's *exit* — not the boot itself. This approach works
        correctly even when Plymouth starts from the initramfs (systemd initrd).
      '';
    };

    custom.sysNixPlymouth.minShutdownDuration = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Minimum time (in seconds) the Plymouth shutdown/reboot splash
        should be visible. On fast systems, shutdown can complete so
        quickly that the splash is barely seen. This adds an ExecStartPre
        sleep to plymouth-poweroff.service and plymouth-reboot.service,
        delaying their exit.

        Set to null (default) to let shutdown proceed at full speed.
      '';
    };

    custom.sysNixPlymouth.debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Plymouth debug logging. Writes detailed debug output to
        /var/log/plymouth-debug.log. Useful for troubleshooting theme
        rendering, display transitions, or multi-monitor issues.
      '';
    };
  };

  config = lib.mkIf config.custom.sysNixPlymouth.enable {
    boot.plymouth = {
      enable = true;

      # logo = "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
      # font = "${pkgs.dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf";
      # theme = "bgrt";
    };

    boot.plymouth.extraConfig =
      # Start Plymouth immediately — Plymouth's default ShowDelay is already 0,
      # but we set it explicitly to be clear and prevent upstream changes from
      # introducing a delay that would flash the bare console before the splash.
      "ShowDelay=0\n"
      +
        # Keep the firmware (UEFI POST) background colour rather than
        # clearing to black, for a seamless POST → Plymouth transition.
        "UseFirmwareBackground=false\n"
      +
        # HiDPI integer scaling factor — only included when deviceScale is set.
        lib.optionalString (
          config.custom.sysNixPlymouth.deviceScale != null
        ) "DeviceScale=${toString config.custom.sysNixPlymouth.deviceScale}\n";

    # Use systemd-based initrd for smooth Plymouth transitions.
    # Without this, Plymouth uses shell script hooks which can cause
    # brief flickers between GRUB → splash → login screen.
    boot.initrd.systemd.enable = true;

    # Suppress initrd status messages that can bleed through before
    # Plymouth takes over the display.
    boot.initrd.verbose = false;

    # Silent boot — suppress all text output so only the Plymouth
    # animation is visible between GRUB and the login screen.
    boot.kernelParams = [
      "quiet"
      "loglevel=3"
      "rd.udev.log_level=3"
      "systemd.show_status=auto" # auto: hide successful status lines, still show errors
      "vt.global_cursor_default=0"
      "logo.nologo" # suppress NixOS/Tux fbcon logo in the corner
      "fbcon=vc:2-6" # keep fbcon off VT1 so it can't flash during GPU driver swap
      "plymouth.nolog" # disable Plymouth boot log (/var/log/boot.log) & console redirection
    ]
    ++ config.custom.sysNixPlymouth.bootVideoParams
    ++ map (connector: "video=${connector}:d") config.custom.sysNixPlymouth.bootDisabledOutputs
    ++ lib.optional (!config.custom.sysNixPlymouth.useSimpleDrm) "plymouth.use-simpledrm=0"
    ++ lib.optional config.custom.sysNixPlymouth.debug "plymouth.debug";

    # Lower console log level to prevent kernel messages from
    # bleeding through the Plymouth splash.
    boot.consoleLogLevel = 0;

    # Preview Plymouth from your desktop session.
    # plymouth-preview: starts the splash on tty6 for 5 seconds, then quits.
    # plymouth-quit:    safety escape if the preview gets stuck.
    environment.shellAliases = {
      plymouth-preview = "sudo plymouthd --mode=boot --tty=/dev/tty6 --kernel-command-line='quiet splash' && sudo plymouth show-splash && sleep 5 && sudo plymouth quit";
      plymouth-preview-shutdown = "sudo plymouthd --mode=shutdown --tty=/dev/tty6 --kernel-command-line='quiet splash' && sudo plymouth show-splash && sleep 5 && sudo plymouth quit";
      plymouth-quit = "sudo plymouth quit";
    };

    # Re-enable outputs that were disabled via video=<connector>:d
    # before the display manager starts, so the login screen sees all monitors.
    systemd.services.plymouth-reenable-outputs =
      lib.mkIf (config.custom.sysNixPlymouth.bootDisabledOutputs != [ ])
        {
          description = "Re-enable DRM outputs disabled during boot";
          wantedBy = [ "display-manager.service" ];
          before = [ "display-manager.service" ];
          after = [ "plymouth-quit.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script =
            lib.concatMapStringsSep "\n" (connector: ''
              for card in /sys/class/drm/card*-${connector}; do
                if [ -e "$card/status" ]; then
                  echo "detect" > "$card/status" 2>/dev/null || true
                  echo "Re-enabled $card"
                fi
              done
            '') config.custom.sysNixPlymouth.bootDisabledOutputs
            + ''
              ${pkgs.udev}/bin/udevadm settle --timeout=5
            '';
        };

    # Ensure the full Plymouth animation plays on fast-booting systems.
    # Adding ExecStartPre to plymouth-quit.service delays Plymouth's exit
    # until the specified duration has elapsed. This approach works even
    # when Plymouth starts from the initramfs (the standalone-service
    # approach does NOT work with initramfs-based Plymouth).
    # https://wiki.archlinux.org/title/Plymouth#Slow_down_boot_to_show_the_full_animation
    systemd.services.plymouth-quit =
      lib.mkIf (config.custom.sysNixPlymouth.minAnimationDuration != null)
        {
          serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString config.custom.sysNixPlymouth.minAnimationDuration}";
        };

    # Ensure the Plymouth shutdown/reboot splash is visible on fast systems.
    # Same ExecStartPre approach as boot, applied to plymouth-poweroff and
    # plymouth-reboot services.
    systemd.services.plymouth-poweroff =
      lib.mkIf (config.custom.sysNixPlymouth.minShutdownDuration != null)
        {
          serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString config.custom.sysNixPlymouth.minShutdownDuration}";
        };
    systemd.services.plymouth-reboot =
      lib.mkIf (config.custom.sysNixPlymouth.minShutdownDuration != null)
        {
          serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString config.custom.sysNixPlymouth.minShutdownDuration}";
        };

    # Disable secondary outputs again before the shutdown/reboot splash.
    # The display manager re-enables all monitors, so outputs disabled during boot (via
    # bootDisabledOutputs) are active again by shutdown time. This service
    # disables them before Plymouth starts, giving a clean single-monitor
    # shutdown splash matching the boot experience.
    systemd.services.plymouth-disable-outputs-on-shutdown =
      lib.mkIf (config.custom.sysNixPlymouth.bootDisabledOutputs != [ ])
        {
          description = "Disable secondary DRM outputs before shutdown/reboot splash";
          wantedBy = [
            "poweroff.target"
            "reboot.target"
            "halt.target"
          ];
          before = [
            "plymouth-start.service"
            "plymouth-halt.service"
            "plymouth-poweroff.service"
            "plymouth-reboot.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            DefaultDependencies = false;
          };
          script = lib.concatMapStringsSep "\n" (connector: ''
            for card in /sys/class/drm/card*-${connector}; do
              if [ -e "$card/dpms" ]; then
                echo "Off" > "$card/dpms" 2>/dev/null || true
                echo "DPMS off $card for shutdown splash"
              fi
            done
          '') config.custom.sysNixPlymouth.bootDisabledOutputs;
        };
  };
}
