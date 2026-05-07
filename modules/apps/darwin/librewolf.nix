# LibreWolf — Darwin app façade
#
# Cross-layer module that owns the Homebrew cask `librewolf` AND wires the
# matching home-manager wrapper under `custom.appLibrewolf.enable`. Hosts
# should not also touch `homebrew.casks` for librewolf or
# `custom.hmLibrewolf.enable` directly.
#
# The HM darwin wrapper enables `programs.librewolf` with `package = null`
# so HM only writes `~/Library/Application Support/LibreWolf/librewolf.overrides.cfg`
# (the cask provides the binary). LibreWolf's HM module accepts a null
# package, so no `home.file` bypass is needed here — compare with VS Code
# whose HM module rejects null and forces a different pattern.
#
# Note: the `librewolf` cask is flagged for Homebrew deprecation in
# Sep 2026 — revisit before then. If the cask goes away, options are
# (a) unsigned tap, (b) drop LibreWolf on darwin and use Brave/Firefox
# instead, or (c) accept Gatekeeper friction with a manual install.
#
# Usage:
#   imports = [ ../../../modules/apps/darwin/librewolf.nix ];
#   custom.appLibrewolf.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appLibrewolf;
in
{
  options.custom.appLibrewolf.enable = lib.mkEnableOption "LibreWolf browser (Homebrew cask + declarative HM settings via home.file)";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "librewolf" ];

    home-manager.users.${userSettings.username} = {
      imports = [ ../../home-manager/darwin/librewolf.nix ];
      custom.hmLibrewolf.enable = true;
    };
  };
}
