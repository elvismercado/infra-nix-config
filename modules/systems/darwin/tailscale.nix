# Tailscale — WireGuard-based mesh VPN client (darwin).
#
# Installs the official Tailscale macOS GUI app via Homebrew cask. The app
# bundles its own network-extension daemon and provides a menu-bar UI for
# connect/disconnect, peer list, and exit-node selection.
#
# Symmetric with the NixOS counterpart `custom.sysNixTailscale`, but macOS
# has no headless-vs-GUI split worth automating here: the cask is the normal
# Mac experience. Do NOT also enable nix-darwin's `services.tailscale` — that
# installs a second, headless `tailscaled` that would conflict with the app's
# bundled daemon.
#
# Authentication: log in interactively via the menu-bar app on first launch
# (the reusable auth key in the private overlay is for the headless NixOS
# hosts, not the GUI app).
#
# Cask name: `tailscale-app` (formerly `tailscale`; verified on
# https://formulae.brew.sh/cask/tailscale-app).
#
# Usage:
#   imports = [ ../../../modules/systems/darwin/tailscale.nix ];
#   custom.sysDarTailscale.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysDarTailscale;
in
{
  options.custom.sysDarTailscale = {
    enable = lib.mkEnableOption "Tailscale mesh-VPN client (macOS GUI app via Homebrew cask)";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "tailscale-app" ];
  };
}
