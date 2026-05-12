# Manage dotfiles and user packages

{
  ...
}:

{
  imports = [
    # Host
    ./home.nix

    # Base
    ../../../modules/home-manager/all/base.nix

    # Shell
    ../../../modules/home-manager/all/aliases.nix
    ../../../modules/home-manager/all/ansible.nix
    ../../../modules/home-manager/all/bash.nix
    ../../../modules/home-manager/all/fastfetch.nix
    ../../../modules/home-manager/all/fnm.nix
    ../../../modules/home-manager/all/git.nix
    ../../../modules/home-manager/all/pyenv.nix
    ../../../modules/home-manager/all/ssh.nix
    ../../../modules/home-manager/all/starship.nix

    # Apps
    ../../../modules/home-manager/all/android.nix

    # macOS
    ../../../modules/home-manager/darwin/rectangle.nix
    ../../../modules/home-manager/darwin/aliases.nix
  ];

  # Base
  custom.hmBase.enable = true;

  # Shell
  custom.hmAliases.enable = true;
  custom.hmAnsible.enable = true;
  custom.hmBash.enable = true;
  custom.hmFastfetch.enable = true;
  custom.hmFnm.enable = true;
  custom.hmGit.enable = true;
  custom.hmPyenv.enable = true;
  custom.hmSsh.enable = true;
  custom.hmStarship.enable = true;
  custom.hmStarship.style = "pastel-powerline";

  # Apps
  custom.hmAndroid.enable = true; # adb/scrcpy used on macOS for device work

  # macOS
  custom.hmRectangle.enable = true;
  custom.hmDarwinAliases.enable = true;
}
