# GRUB bootloader — EFI boot configuration
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/bootloader/grub.nix ];
#   custom.sysNixGrub.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    custom.sysNixGrub.enable = lib.mkEnableOption "GRUB EFI bootloader (configurable timeout)";

    custom.sysNixGrub.timeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = ''
        Seconds to show the GRUB menu before auto-booting the default entry.
        Set to 0 to boot immediately (hold Shift to force menu).
      '';
    };

    custom.sysNixGrub.gfxmodeEfi = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        GRUB EFI graphics mode. Use a comma-separated fallback chain
        for multi-monitor setups, e.g. "2560x1440,auto".
        "auto" lets GRUB pick the best available mode — often
        800x600/1024x768, which makes the menu font look enormous on
        high-DPI panels. Set per host to a real chain such as
        "3840x2160,2560x1440,1920x1080,auto".
      '';
    };

    custom.sysNixGrub.disableSplash = lib.mkEnableOption "disable the NixOS branded GRUB splash image (wordmark/snowflake)";

    custom.sysNixGrub.useOSProber = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `true` (default), GRUB runs `os-prober` at install /
        rebuild time to scan every block device for other operating
        systems (Windows, other Linux installs) and adds them as menu
        entries. Required on dual-boot hosts (e.g. FENNEC).

        On single-OS hosts (a single NixOS install with no other
        bootable partitions) set this to `false`. `os-prober` cannot
        find anything to add and only produces noisy chroot errors on
        every rebuild:

            ERROR: mkdir /var/lock/dmraid
            modprobe: can't change directory to '/lib/modules': No such file or directory

        Those errors are harmless but train the eye to ignore real
        `ERROR:` lines in the install / switch log.
      '';
    };

    custom.sysNixGrub.fontSize = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 32;
      description = ''
        Console font size (in pixels) used by the GRUB menu and editor.
        Important on high-DPI panels: at 4K the default ~16px font looks
        tiny in the menu and the editor (`e`) drops to a low-res fallback
        that scales the bitmap font up to a chunky, hard-to-read size.
        Setting this loads DejaVu Sans Mono at the requested size and
        keeps the editor legible.
        Null = NixOS default (no custom font).
      '';
    };
  };

  config = lib.mkIf config.custom.sysNixGrub.enable {
    boot.loader = {
      timeout = config.custom.sysNixGrub.timeout;
      efi = {
        canTouchEfiVariables = true;
      };
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        configurationLimit = 20;

        # Resolution — use the host-configured mode for a crisp boot menu.
        # "keep" passes the resolution to the kernel, so the console and
        # Plymouth inherit it without a mode switch.
        # Set custom.sysNixGrub.gfxmodeEfi per host (e.g. "2560x1440,auto").
        gfxmodeEfi = config.custom.sysNixGrub.gfxmodeEfi;
        gfxpayloadEfi = "keep";

        # OS prober — auto-detect other OSes (Windows, other Linux) on disk
        # and add them as GRUB menu entries. NixOS includes the os-prober
        # package automatically. Disable on single-OS hosts to silence
        # noisy chroot errors (see `custom.sysNixGrub.useOSProber`).
        useOSProber = config.custom.sysNixGrub.useOSProber;

        # Memtest86+ — memory diagnostic tool in the boot menu.
        # Reboot and select "Memtest86+" from the GRUB menu to test RAM.
        memtest86.enable = true;
      }
      // lib.optionalAttrs (config.custom.sysNixGrub.fontSize != null) {
        # Custom scalable font for the editor + menu. NixOS converts the
        # TTF to PFF2 at install time. DejaVu Sans Mono is the de-facto
        # standard for GRUB; ships in pkgs.dejavu_fonts.
        font = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
        fontSize = config.custom.sysNixGrub.fontSize;
      }
      // lib.optionalAttrs config.custom.sysNixGrub.disableSplash {
        # Suppress NixOS's default branded splash (wordmark + snowflake).
        # mkForce overrides the NixOS module's mkDefault assignment.
        splashImage = lib.mkForce null;
      };
    };
  };
}
