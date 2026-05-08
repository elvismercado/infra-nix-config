{
  description = "NixOS with Home Manager";

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable

    # nixpkgs-stable.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/*"; # latest stable

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master"; # unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin-stable = {
      # url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/*"; # latest stable
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    home-manager = {
      url = "github:nix-community/home-manager"; # unstable (master)
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      # url = "github:nix-community/home-manager/release-25.11";
      url = "https://flakehub.com/f/nix-community/home-manager/*"; # latest stable
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # plasma-manager follows stable inputs only. If a NixOS host ever uses
    # channel = "unstable", a second plasma-manager input (following the unstable
    # variants) would be needed, or the follows must be made channel-aware.
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.home-manager.follows = "home-manager-stable";
    };

    # determinate.url = "github:DeterminateSystems/determinate";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      # Host configurations are defined in ./flake/default.nix
      configurations = import ./flake { inherit self inputs; };

      # Systems are derived from host configurations
      forAllSystems = nixpkgs.lib.genAttrs configurations.systems;
    in
    {
      # Official Nix formatter, available through 'nix fmt'
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      inherit (configurations) nixosConfigurations darwinConfigurations homeConfigurations metadata;
    };
}
