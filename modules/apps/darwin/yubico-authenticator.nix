# Yubico Authenticator — Darwin app façade (install-only)
#
# Cross-layer module that installs Yubico Authenticator under one host-facing
# toggle (`custom.appYubicoAuthenticator.enable`) shared with the Linux
# façade. As of 2024+ this app absorbed the YubiKey Manager configuration UI,
# so a single GUI covers both OATH/TOTP code generation and key management
# (FIDO2, OATH, PIV, OpenPGP slots, PINs, factory reset, etc.).
#
# On darwin the binary comes from the Homebrew cask `yubico-authenticator`.
#
# YubiKey-based system login on macOS (pam-u2f, screensaver/sudo PAM) is a
# separate, system-level concern not yet wired in this repo — see the
# parallel `modules/systems/nixos/security/yubikey.nix` for the Linux
# precedent.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/yubico-authenticator.nix ];
#   custom.appYubicoAuthenticator.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appYubicoAuthenticator;
in
{
  options.custom.appYubicoAuthenticator.enable =
    lib.mkEnableOption "Yubico Authenticator (OATH GUI + key management — Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "yubico-authenticator" ];
  };
}
