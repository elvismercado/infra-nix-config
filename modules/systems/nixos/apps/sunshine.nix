# Sunshine — self-hosted game/desktop streaming host (Moonlight-compatible)
#
# Enables the Sunshine service with autostart, opens the firewall, and uses
# `userSettings.hostname` as the advertised name (overridable).
#
# Web UI credentials are seeded on every boot via a oneshot using
# `userSettings.username` as BOTH the user and the password. This skips
# Sunshine's first-launch wizard so the host is immediately usable on the
# LAN. Caveats:
#   - LAN-only convenience. The password equals the username (public info),
#     so do NOT expose Sunshine's :47990 port beyond the LAN.
#   - Self-healing: any manual password change is reset on the next rebuild
#     or reboot. Replace this seed (or add a `sunshinePassword` override)
#     before exposing the host more widely.
#   - The credentials end up in `/nix/store` via the systemd unit script.
#     Acceptable here because the password equals the username (already
#     public).
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/apps/sunshine.nix ];
#   custom.sysNixSunshine.enable = true;

{
  config,
  pkgs,
  lib,
  userSettings, # from user-settings.nix
  ...
}:

{
  options = {
    custom.sysNixSunshine.enable = lib.mkEnableOption "Sunshine game/desktop streaming host (Moonlight-compatible) with autostart and firewall rules";
  };

  config = lib.mkIf config.custom.sysNixSunshine.enable {
    environment.systemPackages = with pkgs; [
      sunshine
    ];

    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
      settings = {
        sunshine_name = lib.mkDefault userSettings.hostname;
      };
    };

    # Seed Web UI credentials before the main Sunshine service starts.
    # Idempotent: `sunshine --creds` just rewrites the hashed entry in
    # /var/lib/sunshine/sunshine_state.json. Runs every boot so the host
    # self-heals back to known credentials after any rebuild.
    systemd.services.sunshine-seed-creds = {
      description = "Seed Sunshine Web UI credentials (user = password = userSettings.username)";
      wantedBy = [ "multi-user.target" ];
      before = [ "sunshine.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.sunshine}/bin/sunshine --creds ${userSettings.username} ${userSettings.username}
      '';
    };
  };
}
