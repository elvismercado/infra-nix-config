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

  inherit systems;
}
