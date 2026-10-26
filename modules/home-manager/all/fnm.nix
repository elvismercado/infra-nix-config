# fnm — Fast Node Manager
# https://github.com/Schniz/fnm
#
# Fast, cross-platform Node.js version manager written in Rust.
# Works on Linux + macOS. Alternative to nvm with better performance.
#
# On first activation, installs the latest LTS Node.js version and sets it
# as default if no versions are installed yet.
#
# Usage:
#   imports = [ ../../../modules/home-manager/all/fnm.nix ];
#   custom.hmFnm.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options = {
    custom.hmFnm.enable = lib.mkEnableOption "fnm Fast Node Manager (auto-installs latest LTS on first activation)";
  };

  config = lib.mkIf config.custom.hmFnm.enable {
    home.packages = [ pkgs.fnm ];

    # Initialize fnm in bash and zsh (adds the selected Node version to PATH
    # and enables automatic switching based on project version files).
    programs.bash = {
      enable = true;
      initExtra = ''
        eval "$(fnm env --use-on-cd)"
      '';
    };

    programs.zsh = lib.mkIf pkgs.stdenv.isDarwin {
      enable = true;
      initExtra = ''
        eval "$(fnm env --use-on-cd --shell zsh)"
      '';
    };

    # Install latest LTS Node.js and set as default if no versions are installed yet
    home.activation.fnmInstallLts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v fnm &>/dev/null; then
        if [ -z "$(fnm list 2>/dev/null | grep -v 'system')" ]; then
          echo "[fnm] No Node.js versions found, installing latest LTS..."
          fnm install --lts || echo "[fnm] Failed to install Node.js"
          fnm default lts-latest 2>/dev/null || true
          echo "[fnm] Set default Node.js to $(fnm current 2>/dev/null)"
        fi
      fi
    '';
  };
}
