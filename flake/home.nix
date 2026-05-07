{
  self,
  inputs,
  homeManagerHosts,
  selectNixpkgs,
  selectHomeManager,
}:
let
  inherit (inputs) nixpkgs;
in
nixpkgs.lib.genAttrs (builtins.attrNames homeManagerHosts) (
  hostName:
  let
    userSettings = homeManagerHosts.${hostName}.userSettings;
    selectedNixpkgs = selectNixpkgs userSettings;
    selectedHomeManager = selectHomeManager userSettings;
  in
  selectedHomeManager.lib.homeManagerConfiguration {
    pkgs = selectedNixpkgs.legacyPackages.${userSettings.system};
    modules = [
      { nixpkgs.config.allowUnfree = true; }
      homeManagerHosts.${hostName}.home
    ]
    ++ nixpkgs.lib.optional (
      builtins.match ".*linux.*" userSettings.system != null
      && (userSettings.desktopEnvironment or null) == "kde-plasma"
    ) inputs.plasma-manager.homeModules.plasma-manager;
    extraSpecialArgs = {
      outputs = self.outputs;
      inherit inputs;
      inherit userSettings;
    };
  }
)
