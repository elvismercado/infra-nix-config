{
  self,
  inputs,
  darwinHosts,
  selectNixpkgs,
  selectHomeManager,
  selectDarwin,
}:
let
  inherit (inputs) nixpkgs determinate;
in
nixpkgs.lib.genAttrs (builtins.attrNames darwinHosts) (
  hostName:
  let
    userSettings = darwinHosts.${hostName}.userSettings;
    selectedNixpkgs = selectNixpkgs userSettings;
    selectedHomeManager = selectHomeManager userSettings;
    selectedDarwin = selectDarwin userSettings;
  in
  selectedDarwin.lib.darwinSystem {
    system = userSettings.system;
    modules = [
      {
        nixpkgs.config = {
          allowUnfree = true;
          allowDeprecatedx86_64Darwin = userSettings.system == "x86_64-darwin";
        };
        # Use the selected nixpkgs channel for this host
        nixpkgs.source = selectedNixpkgs.outPath;
      }
      determinate.darwinModules.default
      selectedHomeManager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.extraSpecialArgs = {
          outputs = self.outputs;
          inherit inputs userSettings;
        };
        home-manager.users.${userSettings.username}.imports = [
          darwinHosts.${hostName}.home
        ];
      }
      darwinHosts.${hostName}.configuration
    ];
    specialArgs = {
      outputs = self.outputs;
      inherit inputs;
      inherit userSettings;
    };
  }
)
