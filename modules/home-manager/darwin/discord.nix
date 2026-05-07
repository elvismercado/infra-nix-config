# Discord client — Darwin wrapper for the cross-platform discord core module.
#
# Binary is provided by the Homebrew cask `vesktop` (declared by the
# Option 3 app façade in `modules/apps/darwin/discord.nix`) — the preferred
# Discord client per the binary policy in `core/discord.nix`. There is no
# HM-side declarative config to add for vesktop on darwin.
#
# Internal once the Option 3 app façade is in use: imported by
# `modules/apps/darwin/discord.nix`. Hosts should normally not import this
# file directly.

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.hmDiscord;
in
{
  imports = [ ../core/discord.nix ];

  config = lib.mkIf cfg.enable {
    # Cask provides the binary; nothing to wire here yet.
  };
}
