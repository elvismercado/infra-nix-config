# LibreWolf — shared cross-platform core
#
# Declares the `custom.hmLibrewolf.enable` toggle and a shared
# `custom.hmLibrewolf.settings` attrset used by both per-OS wrappers.
# This file holds NO `config` block — wrappers own the actual writing.
#
#   - Linux wrapper:  feeds `cfg.settings` to `programs.librewolf.settings`
#                     (HM installs nixpkgs librewolf and writes
#                     `~/.librewolf/librewolf.overrides.cfg`).
#   - Darwin wrapper: same `programs.librewolf` module, but with
#                     `package = null` so HM only writes
#                     `~/Library/Application Support/LibreWolf/librewolf.overrides.cfg`
#                     while the Homebrew cask `librewolf` provides the binary.
#                     LibreWolf's HM module accepts `package = null` (its
#                     option type is `nullOr package` and it guards
#                     `cfg.finalPackage != null` before referencing it).
#
# `custom.hmLibrewolf.settings` matches upstream's settings type
# (`attrsOf (either bool (either int str))`), so hosts can extend it
# per-key via normal module-system merging. HM only writes the overrides
# file when the attrset is non-empty.
#
# Internal — do not import from hosts. Imported by `linux/librewolf.nix` and
# `darwin/librewolf.nix`. In normal use, hosts wire LibreWolf through the
# Option 3 app façade `modules/apps/{linux,darwin}/librewolf.nix`.

{ lib, ... }:

{
  options.custom.hmLibrewolf = {
    enable =
      lib.mkEnableOption "LibreWolf browser (privacy-hardened Firefox fork; nixpkgs binary on Linux, Homebrew cask on Darwin)";

    settings = lib.mkOption {
      type = with lib.types; attrsOf (either bool (either int str));
      default = { };
      example = lib.literalExpression ''
        {
          "webgl.disabled" = false;
          "privacy.resistFingerprinting" = false;
        }
      '';
      description = ''
        Attribute set of LibreWolf preference overrides written to
        `librewolf.overrides.cfg`. Refer to <https://librewolf.net/docs/settings/>
        for supported keys. Defaults to an empty set so unmentioned preferences
        keep LibreWolf's hardened defaults.
      '';
    };
  };
}
