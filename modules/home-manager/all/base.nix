# Base home-manager config — environment variables, core packages
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/base.nix ];
#   custom.hmBase.enable = true;

{
  config,
  pkgs,
  lib,
  ...
}:

{
  options.custom.hmBase = {
    enable = lib.mkEnableOption "shared Home Manager base config (env vars, core packages, default editor)";
    editor = lib.mkOption {
      type = lib.types.str;
      default = "nano";
      description = "Default editor for EDITOR env var and git core.editor.";
    };
  };

  config = lib.mkIf config.custom.hmBase.enable {
    home.packages = with pkgs; [
      nixfmt-tree
      nil

      # --- terminal eye candy ---
      cowsay
      lolcat
      unimatrix # Matrix-style terminal rain (cmatrix successor with more character sets)
      cbonsai # ASCII bonsai tree generator with live-growing mode
      genact # Fake activity generator (npm install, kernel compile, etc.)

      mullvad-closest # Find Mullvad servers with the lowest latency at your location

      headsetcontrol # Sidetone and Battery status for Logitech G930, G533, G633, G933 SteelSeries Arctis 7/PRO 2019 and Corsair VOID (Pro)
    ];

    home.sessionVariables = {
      EDITOR = config.custom.hmBase.editor;
    };
  };
}
