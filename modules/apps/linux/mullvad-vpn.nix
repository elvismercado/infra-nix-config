# Mullvad VPN — Linux app façade (system + HM hybrid)
#
# Cross-layer module that wires Mullvad VPN under one host-facing toggle
# (`custom.appMullvadVpn.enable`) shared with the darwin façade. Owns BOTH
# the system-level daemon (services.mullvad-vpn) and the HM-level GUI/CLI
# binaries (`pkgs.mullvad-vpn` ships both `mullvad-vpn` GUI and `mullvad`
# CLI).
#
# WireGuard-based kill-switch requires loose reverse-path filtering.
# Without this, packets routed through the WireGuard tunnel are dropped by
# the kernel's strict rp_filter check. See:
#   https://nixos.wiki/wiki/Mullvad_VPN
#
# Autostart: this façade does not register an autostart entry. If you want
# the GUI to launch at login, add it to your host's `custom.hmAutostart.entries`
# (Mullvad has no `--minimized` flag — it minimises to tray on close, which
# Mullvad remembers across sessions).
#
# Usage:
#   imports = [ ../../../modules/apps/linux/mullvad-vpn.nix ];
#   custom.appMullvadVpn.enable = true;

{
  config,
  lib,
  pkgs,
  userSettings,
  ...
}:

let
  cfg = config.custom.appMullvadVpn;
in
{
  options.custom.appMullvadVpn.enable = lib.mkEnableOption "Mullvad VPN (services.mullvad-vpn daemon + GUI/CLI client; rp_filter loose for WireGuard kill-switch)";

  config = lib.mkIf cfg.enable {
    services.mullvad-vpn.enable = true;

    # WireGuard kill-switch: kernel must not drop packets returned via the
    # tunnel. Strict rp_filter would. mkDefault so hosts can override.
    networking.firewall.checkReversePath = lib.mkDefault "loose";

    # GUI client + `mullvad` CLI in the user's HM packages — discoverable in
    # KDE/GNOME launchers and on PATH.
    home-manager.users.${userSettings.username}.home.packages = [ pkgs.mullvad-vpn ];
  };
}
