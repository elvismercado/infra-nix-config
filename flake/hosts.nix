{ inputs }:
let
  validChannels = [
    "stable"
    "unstable"
  ];

  mkHost =
    hostName:
    let
      publicUserSettings = import ../hosts/${hostName}/user-settings.nix;
      # Optional private overlay (sibling repo, gitignored from the public
      # tree). Holds PII-bearing fields like `timeZone`. When the overlay
      # path doesn't exist, fall back to an empty attrset so the public
      # repo evaluates standalone.
      privateOverlayPath = ../../nix-config-private/hosts/${hostName}/user-settings.nix;
      privateUserSettings =
        if builtins.pathExists privateOverlayPath then import privateOverlayPath else { };
      userSettings = publicUserSettings // privateUserSettings;
    in
    if !(builtins.elem userSettings.channel validChannels) then
      throw "Host '${hostName}': channel must be one of ${builtins.toJSON validChannels}, got '${toString userSettings.channel}'"
    else
      {
        configuration = ../hosts/${hostName}/configuration;
        home = ../hosts/${hostName}/home-manager;
        inherit userSettings;
      };

  # Select inputs based on the host's channel setting ("stable" or "unstable")
  selectNixpkgs =
    settings: if settings.channel == "stable" then inputs.nixpkgs-stable else inputs.nixpkgs;

  selectHomeManager =
    settings: if settings.channel == "stable" then inputs.home-manager-stable else inputs.home-manager;

  selectDarwin =
    settings: if settings.channel == "stable" then inputs.nix-darwin-stable else inputs.nix-darwin;

  nixosHosts = {
    # `sudo nixos-rebuild switch --flake .#JIN`
    JIN = mkHost "JIN";

    # `sudo nixos-rebuild switch --flake .#FENNEC`
    FENNEC = mkHost "FENNEC";
  };

  darwinHosts = {
    # `sudo darwin-rebuild switch --flake .#EDGE`
    EDGE = mkHost "EDGE";

    # `sudo darwin-rebuild switch --flake .#LULA`
    LULA = mkHost "LULA";
  };

  # Standalone home-manager hosts — for systems without NixOS/nix-darwin
  # module integration (e.g. Arch Linux, Ubuntu).
  # NixOS and darwin hosts get home-manager via their system rebuild.
  # Usage: `home-manager switch --flake .#<HOST>`
  homeManagerHosts = {
  };
in
{
  inherit
    mkHost
    selectNixpkgs
    selectHomeManager
    selectDarwin
    nixosHosts
    darwinHosts
    homeManagerHosts
    ;
}
