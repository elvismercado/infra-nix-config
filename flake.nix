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

    # Private overlay sibling repo (gitignored from the public tree).
    # Holds PII-bearing per-host fields (timeZone, language, regionalFormat,
    # syncthing IDs/addresses). Expected to live next to this repo on disk:
    #
    #   git clone <public>  nix-config
    #   git clone <private> nix-config-private
    #
    # `flake = false` means we treat it as a plain source tree, not a flake.
    # `git+file:` (rather than `path:`) is used because plain
    # `path:../nix-config-private` mis-parses on Determinate Nix as
    # `error: 'nix-config-private' is too short to be a valid store path`.
    # `git+file:` resolves the relative path against this flake's parent
    # directory and copies the git-tracked files into the store.
    #
    # Caveat: only committed overlay files are visible. Uncommitted edits
    # in the sibling repo won't be picked up until you `git add && commit`.
    #
    # If the sibling is missing, `nix flake check` (and any rebuild) will
    # fail with `cannot read input 'private'`. Bootstrap by cloning the
    # sibling — see README "PII & Secrets Discipline".
    private = {
      url = "git+file:../nix-config-private";
      flake = false;
    };
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
