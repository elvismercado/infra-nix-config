# Yubico Authenticator — Linux app façade (install-only)
#
# Cross-layer module that installs Yubico Authenticator under one host-facing
# toggle (`custom.appYubicoAuthenticator.enable`) shared with the darwin
# façade. As of 2024+ this app absorbed the YubiKey Manager configuration UI,
# so a single GUI covers both OATH/TOTP code generation and key management
# (FIDO2, OATH, PIV, OpenPGP slots, PINs, factory reset, etc.).
#
# On Linux the binary comes from nixpkgs `yubioath-flutter` (the modern
# Flutter rewrite — superseded the older `yubikey-manager-qt` GUI).
#
# YubiKey-based system login (PAM / pam_u2f / pcscd / udev rules) is a
# separate, system-level concern and lives in
# `modules/systems/nixos/security/yubikey.nix` — not here.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/yubico-authenticator.nix ];
#   custom.appYubicoAuthenticator.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appYubicoAuthenticator;
in
{
  options.custom.appYubicoAuthenticator.enable =
    lib.mkEnableOption "Yubico Authenticator (OATH GUI + key management — nixpkgs binary, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.yubioath-flutter ];
  };
}
