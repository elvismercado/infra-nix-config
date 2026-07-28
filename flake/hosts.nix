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
      # Private overlay merged in from the `private` flake input
      # (companion `infra-nix-config-private` repo). Holds PII-bearing fields like
      # `timeZone`, `language`, `regionalFormat`. The `pathExists` guard
      # handles the case where the sibling exists but a per-host overlay
      # file hasn't been created yet (e.g. a freshly-added host).
      privateOverlayPath = inputs.private + "/hosts/${hostName}/user-settings.nix";
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

    # `sudo nixos-rebuild switch --flake .#LULA`
    LULA = mkHost "LULA";
  };

  darwinHosts = {
    # `sudo darwin-rebuild switch --flake .#EDGE`
    EDGE = mkHost "EDGE";
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
