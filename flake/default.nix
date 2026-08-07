{
  self,
  inputs,
}:
let
  inherit (inputs) nixpkgs;
  hosts = import ./hosts.nix { inherit inputs; };
  inherit (hosts)
    selectNixpkgs
    selectHomeManager
    selectDarwin
    nixosHosts
    darwinHosts
    homeManagerHosts
    ;

  # Per-host cross-host metadata (auto-discovered from `hosts/*/metadata.nix`).
  # Loaded here so any syntax error surfaces at flake eval time. Exposed
  # as a flake attribute (`nix eval .#metadata.all`) for ad-hoc inspection
  # and for repo-level consumers; module consumers (e.g. syncthing peers)
  # import it directly from `flake/metadata.nix`.
  metadata = import ./metadata.nix {
    inherit (nixpkgs) lib;
    privateSource = inputs.private;
  };

  # Derive the list of unique systems from all host configurations
  allHosts = nixosHosts // darwinHosts // homeManagerHosts;
  systems = nixpkgs.lib.unique (map (host: host.userSettings.system) (builtins.attrValues allHosts));
in
{
  nixosConfigurations = import ./nixos.nix {
    inherit
      self
      inputs
      nixosHosts
      selectNixpkgs
      selectHomeManager
      ;
  };

  darwinConfigurations = import ./darwin.nix {
    inherit
      self
      inputs
      darwinHosts
      selectNixpkgs
      selectHomeManager
      selectDarwin
      ;
  };

  homeConfigurations = import ./home.nix {
    inherit
      self
      inputs
      homeManagerHosts
      selectNixpkgs
      selectHomeManager
      ;
  };

  inherit systems metadata;
}
