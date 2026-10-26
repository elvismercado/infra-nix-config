# uv — Python version and project manager
#
# Provides the uv CLI and a Nix-managed base Python. uv can install project
# Python versions and create isolated project environments as needed.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/uv.nix ];
#   custom.hmUv.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.custom.hmUv.enable = lib.mkEnableOption "uv Python version and project manager";

  config = lib.mkIf config.custom.hmUv.enable {
    home.packages = [
      pkgs.uv
      pkgs.python3
    ];
  };
}
