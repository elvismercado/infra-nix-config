# ProtonMail Bridge — Darwin app façade (install-only)
#
# Cross-layer module that installs the ProtonMail Bridge cask under one
# host-facing toggle (`custom.appProtonmailBridge.enable`) shared with the
# Linux façade. Bridge is configured through its own UI — no HM config to
# wrap.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/proton-mail-bridge.nix ];
#   custom.appProtonmailBridge.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appProtonmailBridge;
in
{
  options.custom.appProtonmailBridge.enable = lib.mkEnableOption "ProtonMail Bridge (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "proton-mail-bridge" ];
  };
}
