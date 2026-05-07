# HandBrake — shared cross-platform core
#
# Declares the `custom.hmHandbrake.enable` toggle. Wrappers add per-OS config:
#
#   - Linux wrapper:  installs `pkgs.handbrake` (GUI) into home.packages.
#   - Darwin wrapper: empty config — the Homebrew cask `handbrake-app`
#                     provides the binary.
#
# Internal — do not import from hosts. Imported by `linux/handbrake.nix` and
# `darwin/handbrake.nix`. In normal use, hosts wire HandBrake through the
# Option 3 app façade `modules/apps/{linux,darwin}/handbrake.nix`.

{ lib, ... }:

{
  options.custom.hmHandbrake.enable =
    lib.mkEnableOption "HandBrake video transcoder GUI (Linux: nixpkgs; Darwin: Homebrew cask)";
}
