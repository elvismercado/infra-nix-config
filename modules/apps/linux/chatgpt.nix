# ChatGPT desktop app for Linux (includes the Codex desktop experience).
#
# JIN uses the stable nixpkgs channel, where the ChatGPT package is not built
# for Linux. Use the repository's already-locked unstable nixpkgs input for
# this application only; the host's selected system package set is unchanged.
# NixOS is not an officially listed Linux desktop-app distribution, so runtime
# and remote-control support remain dependent on the upstream preview.
#
# Usage:
#   imports = [ ../../../modules/apps/linux/chatgpt.nix ];
#   custom.appChatgpt.enable = true;

{
  config,
  inputs,
  lib,
  userSettings,
  ...
}:

let
  cfg = config.custom.appChatgpt;
  chatgptPkgs = import inputs.nixpkgs {
    inherit (userSettings) system;
    config.allowUnfree = true;
  };
in
{
  options.custom.appChatgpt.enable = lib.mkEnableOption
    "ChatGPT desktop app with Codex (pinned unstable nixpkgs package)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${userSettings.username}.home.packages = [ chatgptPkgs.chatgpt ];
  };
}
