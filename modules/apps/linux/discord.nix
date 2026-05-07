# Discord client — Linux app façade
#
# Cross-layer module that wires the Discord client under
# `custom.appDiscord.enable`. The binary on Linux is **Vesktop** (from
# nixpkgs `vesktop`) — see `modules/home-manager/core/discord.nix` for the
# binary policy (vesktop preferred wherever available, with discord as a
# documented fallback for platforms where vesktop is absent).
#
# This façade is a thin forwarder: it pulls the matching HM wrapper into
# HM scope and flips its enable toggle. Hosts should not also touch
# `custom.hmDiscord.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/discord.nix ];
#   custom.appDiscord.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appDiscord;
in
{
  options.custom.appDiscord.enable =
    lib.mkEnableOption "Discord client (vesktop binary from nixpkgs)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/linux/discord.nix ];
      custom.hmDiscord.enable = true;
    };
  };
}
