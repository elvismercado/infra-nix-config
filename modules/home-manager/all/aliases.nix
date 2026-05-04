# Cross-platform shell aliases — nix workflow, diagnostics
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/aliases.nix ];
#   custom.hmAliases.enable = true;

{
  config,
  lib,
  userSettings,
  ...
}:

{
  options = {
    custom.hmAliases.enable = lib.mkEnableOption "cross-platform Home Manager shell aliases (nix workflow, diagnostics)";
  };

  config = lib.mkIf config.custom.hmAliases.enable {
    home.shellAliases = {
      ll = "ls -alF";

      # Nix workflow aliases
      switchcd = "cd ${config.home.homeDirectory}/${userSettings.repoPath}";
      switchupdate = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && nix flake update";
      switchcheck = "cd ${config.home.homeDirectory}/${userSettings.repoPath} && nix flake check";
      switchtrusted = "nix config show | grep trusted-users";

      # --- terminal eye candy ---
      funmatrix = "unimatrix -s 96 -l o"; # Matrix rain (fast, iconic katakana set)
      funbonsai = "cbonsai -l"; # Live-growing ASCII bonsai
      funhack = "genact"; # Fake hacking activity generator
    };
  };
}
