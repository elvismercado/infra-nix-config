# Discord client — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask AND wires the matching
# home-manager wrapper under `custom.appDiscord.enable`.
#
# Binary policy (see `modules/home-manager/core/discord.nix`): prefer
# **Vesktop** wherever available, fall back to upstream `discord` only on
# platforms where vesktop is absent. The vesktop cask is available on
# Homebrew today, so darwin uses it. If the vesktop cask ever disappears,
# swap this line to the `discord` cask and re-evaluate.
#
# Hosts should not also touch `homebrew.casks` for vesktop / discord or
# `custom.hmDiscord.enable` directly.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/discord.nix ];
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
  options.custom.appDiscord.enable = lib.mkEnableOption "Discord client (vesktop binary from Homebrew cask)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "vesktop" ]; # vesktop preferred over discord — see core/discord.nix

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/discord.nix ];
      custom.hmDiscord.enable = true;
    };
  };
}
