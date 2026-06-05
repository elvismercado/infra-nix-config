# RustDesk — Darwin app façade (install-only)
#
# Cross-layer module that installs the RustDesk cask under one host-facing
# toggle (`custom.appRustdesk.enable`) shared with the Linux façade. RustDesk
# is an open-source TeamViewer/AnyDesk alternative — the same binary acts as
# both the controlled host and the controlling client.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/rustdesk.nix ];
#   custom.appRustdesk.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appRustdesk;
in
{
  options.custom.appRustdesk.enable = lib.mkEnableOption "RustDesk remote-desktop client/host (Homebrew cask, install-only)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "rustdesk" ];
  };
}
