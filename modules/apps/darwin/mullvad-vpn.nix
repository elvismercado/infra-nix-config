# Mullvad VPN — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `mullvad-vpn` under one
# host-facing toggle (`custom.appMullvadVpn.enable`) shared with the Linux
# façade. The cask installs the full Mullvad VPN.app including the menubar
# tray.
#
# Login items: macOS handles "Open at Login" through the cask's first-launch
# prompt or the user's Login Items pane in System Settings — there is no
# declarative HM/nix-darwin equivalent, so this is intentionally a per-user
# decision rather than a façade option.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/mullvad-vpn.nix ];
#   custom.appMullvadVpn.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.appMullvadVpn;
in
{
  options.custom.appMullvadVpn.enable =
    lib.mkEnableOption "Mullvad VPN (Homebrew cask, GUI + tray)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "mullvad-vpn" ];
  };
}
