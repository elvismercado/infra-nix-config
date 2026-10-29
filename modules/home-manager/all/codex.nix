# Codex CLI — terminal coding agent
#
# This deliberately uses the flake's pinned unstable nixpkgs input so hosts on
# the stable channel can opt into Codex without changing their system channel.
# Authentication is an interactive per-user step and is not stored in Nix.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/codex.nix ];
#   custom.hmCodex.enable = true;

{
  config,
  inputs,
  lib,
  userSettings,
  ...
}:

let
  codexPkgs = import inputs.nixpkgs {
    inherit (userSettings) system;
  };
in
{
  options.custom.hmCodex.enable = lib.mkEnableOption
    "Codex CLI from the pinned unstable nixpkgs input";

  config = lib.mkIf config.custom.hmCodex.enable {
    home.packages = [ codexPkgs.codex ];
  };
}
