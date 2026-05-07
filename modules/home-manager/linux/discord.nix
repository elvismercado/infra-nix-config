# Discord client — Linux wrapper for the cross-platform discord core module.
#
# Installs **Vesktop** from nixpkgs — the preferred Discord client per the
# binary policy in `core/discord.nix`. Vesktop bundles Vencord plugins and
# delivers native screen-share audio on Wayland/PipeWire.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/linux/discord.nix` (toggle `custom.appDiscord.enable`).
# Hosts should normally not import this file directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/home-manager/linux/discord.nix ];
#   custom.hmDiscord.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmDiscord;
in
{
  imports = [ ../core/discord.nix ];

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.vesktop # vesktop available in nixpkgs — used in preference to pkgs.discord
    ];
  };
}
