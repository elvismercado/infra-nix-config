# Tailscale — WireGuard-based mesh VPN client (NixOS).
#
# Enables the `tailscaled` daemon as a plain client and opens the firewall
# for the tailnet: trusts the `tailscale0` interface, allows the daemon's
# UDP port, and relaxes reverse-path filtering (required for Tailscale's
# direct-connection NAT traversal).
#
# Authentication (non-interactive, per host):
#   Each host has its OWN auth key in the private overlay repo at
#   `nix-config-private/hosts/<HOSTNAME>/secrets/tailscale-authkey` (a
#   single-line key), reached here via the `private` flake input and keyed on
#   `userSettings.hostname` — the same per-host overlay convention used for
#   `user-settings.nix` (see flake/hosts.nix). When the file is present the
#   daemon registers the node automatically on first start; when absent, fall
#   back to a manual `sudo tailscale up`.
#
#   SECURITY: the key file is copied world-readable into /nix/store. Use a
#   TAGGED, EPHEMERAL, SHORT-EXPIRY auth key generated in the Tailscale admin
#   console (https://login.tailscale.com/admin/settings/keys). The key only
#   registers the node — revoke/rotate it freely afterwards; established node
#   state lives in /var/lib/tailscale and survives key revocation.
#
# Manual prerequisite (one-time, per host):
#   1. Tailscale admin console → Settings → Keys → Generate auth key
#      (Ephemeral + a tag, short expiry).
#   2. Write the key to nix-config-private/hosts/<HOSTNAME>/secrets/tailscale-authkey.
#   3. git commit && git push in nix-config-private (only pushed files are
#      visible to the flake build).
#
# Verification after a switch:
#   tailscale status
#   tailscale ip -4
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/network/tailscale.nix ];
#   custom.sysNixTailscale.enable = true;

{
  config,
  lib,
  inputs,
  userSettings,
  ...
}:

let
  cfg = config.custom.sysNixTailscale;

  # Auto-derive the per-host auth key path from the private overlay repo. The
  # pathExists guard mirrors the user-settings overlay pattern in
  # flake/hosts.nix — a host builds cleanly even before its key file exists
  # (interactive `tailscale up` fallback).
  keyPath = inputs.private + "/hosts/${userSettings.hostname}/secrets/tailscale-authkey";
  authKeyFile = if builtins.pathExists keyPath then keyPath else null;
in
{
  options.custom.sysNixTailscale = {
    enable = lib.mkEnableOption "Tailscale mesh-VPN client (tailscaled daemon + firewall trust)";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      inherit authKeyFile;
    };

    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
      checkReversePath = "loose";
    };
  };
}
