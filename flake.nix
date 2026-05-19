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
    # syncthing IDs/addresses).
    #
    # Fetched from a private GitHub repo via the `github:` URL scheme.
    # `flake = false` means we treat it as a plain source tree.
    #
    # ## Why `github:` and not `git+file:` / `path:` / `git+https:`
    #
    # Migrated 2026-05-19. Earlier forms all failed for different reasons:
    #
    #   - `git+file:../nix-config-private` (sibling-on-disk) emits a
    #     deprecation warning on every rebuild
    #     (https://github.com/NixOS/nix/issues/12281) and is slated for
    #     removal.
    #
    #   - `path:../nix-config-private` — broken on Determinate Nix 3.20.0
    #     / Nix 2.34.6. The parent flake is copied into the store first,
    #     so `outPath` resolves to `/nix/store/HASH-source/../nix-config-private`
    #     (escapes the store). `pathExists` then trips
    #     "is too short to be a valid store path". The bare-path-value
    #     form `url = ../foo` uses the same fetcher and is equally broken.
    #
    #   - `git+https://github.com/...` — daemon-side fetcher shells out
    #     to the git subprocess, which does NOT consult Nix's
    #     `access-tokens` setting. `sudo nixos-rebuild` prompts for a
    #     git username/password and fails. Same root cause for
    #     `git+ssh://` (root has no SSH key for GitHub).
    #
    #   - `github:` — uses the GitHub tarball API instead of the git
    #     protocol. This path DOES honour `access-tokens`, so the
    #     daemon authenticates cleanly when invoked as
    #     `--option access-tokens "github.com=$(gh auth token)"`.
    #
    # ## Auth model
    #
    # The token is injected per-invocation via `gh auth token` in the
    # `switch*` aliases in `modules/home-manager/{linux,darwin}/aliases.nix`.
    # Nothing committed, nothing in `/etc/nix/nix.conf`. Each rebuilder
    # needs `gh auth login` (one-time, per user per host).
    #
    # ## Workflow caveat
    #
    # `git+file:` / `path:` read from the local sibling, so edits were
    # visible without pushing. `github:` fetches from GitHub, so edits
    # MUST be both committed AND pushed before they show up in a
    # rebuild. The `bumpPrivate` step in the switch aliases auto-pushes
    # the sibling before refreshing the lock, preserving the
    # "edit + switch" UX.
    private = {
      url = "github:elvismercado/nix-config-private";
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
