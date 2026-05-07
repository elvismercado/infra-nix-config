{
  self,
  inputs,
  nixosHosts,
  selectNixpkgs,
  selectHomeManager,
}:
let
  inherit (inputs) nixpkgs determinate;
in
nixpkgs.lib.genAttrs (builtins.attrNames nixosHosts) (
  hostName:
  let
    userSettings = nixosHosts.${hostName}.userSettings;
    selectedNixpkgs = selectNixpkgs userSettings;
    selectedHomeManager = selectHomeManager userSettings;
  in
  selectedNixpkgs.lib.nixosSystem {
    system = userSettings.system;
    modules = [
      { nixpkgs.config.allowUnfree = true; }
      { nix.settings.trusted-users = [ userSettings.username ]; }
      determinate.nixosModules.default
      selectedHomeManager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = {
          outputs = self.outputs;
          inherit inputs userSettings;
        };
        # plasma-manager input follows nixpkgs-stable / home-manager-stable.
        # Incompatible with channel = "unstable" hosts — see flake.nix.
        home-manager.sharedModules = nixpkgs.lib.optional (
          (userSettings.desktopEnvironment or null) == "kde-plasma"
        ) inputs.plasma-manager.homeModules.plasma-manager;
        home-manager.users.${userSettings.username}.imports = [
          nixosHosts.${hostName}.home
        ];
      }
      nixosHosts.${hostName}.configuration
    ];
    specialArgs = {
      outputs = self.outputs;
      inherit inputs;
      inherit userSettings;
    };
  }
)
