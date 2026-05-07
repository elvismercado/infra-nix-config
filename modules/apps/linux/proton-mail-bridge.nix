# ProtonMail Bridge — Linux app façade (install-only)
#
# Cross-layer module that installs the ProtonMail Bridge GUI under one
# host-facing toggle (`custom.appProtonmailBridge.enable`) shared with the
# darwin façade. Bridge is configured through its own UI (Proton login,
# IMAP/SMTP credentials) — no HM `programs.*` to wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/proton-mail-bridge.nix ];
#   custom.appProtonmailBridge.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appProtonmailBridge;
in
{
  options.custom.appProtonmailBridge.enable =
    lib.mkEnableOption "ProtonMail Bridge (nixpkgs protonmail-bridge-gui, install-only)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.protonmail-bridge-gui ];
  };
}
