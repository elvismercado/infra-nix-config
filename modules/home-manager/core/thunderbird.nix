# Thunderbird — shared cross-platform core
#
# Declares the `custom.hmThunderbird.enable` toggle. This file holds NO
# `config` block — wrappers own the per-OS config because the HM module
# `programs.thunderbird` cannot be used the same way on both OSes:
#
#   - Linux wrapper:  enables `programs.thunderbird` with the default profile
#                     and pulls in hunspell dictionaries.
#   - Darwin wrapper: install-only on the HM side. It does NOT enable
#                     `programs.thunderbird` because that module's `package`
#                     is non-nullable (`mkPackageOption pkgs "thunderbird"`)
#                     and it dereferences `cfg.package` for `home.packages`
#                     and native messaging host registration. Thunderbird
#                     auto-creates its profile on first launch under
#                     `~/Library/Thunderbird/Profiles`, so no scaffolding is
#                     needed. The wrapper just adds the same hunspell
#                     dictionaries; the Homebrew cask `thunderbird` provides
#                     the binary.
#
# This module has no `settings` attrset because the current usage doesn't
# manage Thunderbird preferences declaratively — accounts, identities, and
# user.js are all configured through Thunderbird's GUI. If/when declarative
# settings become useful on Linux, add a typed option here and feed it to
# `programs.thunderbird.profiles.default.settings` from the linux wrapper.
#
# Internal — do not import from hosts. Imported by `linux/thunderbird.nix`
# and `darwin/thunderbird.nix`. In normal use, hosts wire Thunderbird through
# the Option 3 app façade `modules/apps/{linux,darwin}/thunderbird.nix`.

{ lib, ... }:

{
  options.custom.hmThunderbird.enable =
    lib.mkEnableOption "Thunderbird email client (Linux: nixpkgs + declarative profile; Darwin: Homebrew cask, install-only on HM side)";
}
