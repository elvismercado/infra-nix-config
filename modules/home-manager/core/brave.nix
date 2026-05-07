# Brave browser — shared cross-platform core
#
# Declares the `custom.hmBrave.enable` toggle. Wrappers add per-OS config:
#
#   - Linux wrapper:  enables `programs.brave` and (optionally) registers
#                     KDE Plasma's browser-integration native messaging host
#                     when `userSettings.desktopEnvironment = "kde-plasma"`.
#   - Darwin wrapper: empty config — the Homebrew cask `brave-browser` provides
#                     the binary and there is no Plasma integration to wire.
#                     The wrapper exists for OS-symmetric host wiring (every
#                     host enables Brave the same way through the Option 3
#                     façade `custom.appBrave.enable`).
#
# This module has no `settings` attrset because Brave's home-manager module
# does not expose a generic settings option (settings are managed via Brave's
# in-app sync / GUI). If we ever need declarative `nativeMessagingHosts` lists
# beyond the current Plasma-only case, lift them into a typed option here.
#
# Internal — do not import from hosts. Imported by `linux/brave.nix` and
# `darwin/brave.nix`. In normal use, hosts wire Brave through the Option 3
# app façade `modules/apps/{linux,darwin}/brave.nix`.

{ lib, ... }:

{
  options.custom.hmBrave.enable =
    lib.mkEnableOption "Brave browser (Linux: nixpkgs + KDE Plasma integration; Darwin: Homebrew cask)";
}
