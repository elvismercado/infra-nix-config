# Nextcloud desktop client — shared cross-platform core
#
# Declares the `custom.hmNextcloud.enable` toggle. Wrappers add per-OS config:
#
#   - Linux wrapper:  enables `services.nextcloud-client` (autostart + tray).
#   - Darwin wrapper: empty config — the Homebrew cask `nextcloud` provides
#                     the binary; account configuration is GUI-only.
#
# Internal — do not import from hosts. Imported by `linux/nextcloud.nix` and
# `darwin/nextcloud.nix`. In normal use, hosts wire Nextcloud through the
# Option 3 app façade `modules/apps/{linux,darwin}/nextcloud.nix`.

{ lib, ... }:

{
  options.custom.hmNextcloud.enable =
    lib.mkEnableOption "Nextcloud desktop sync client (Linux: nixpkgs service; Darwin: Homebrew cask)";
}
