# Brave managed policies — NixOS writer
#
# Drops the shared policy attrset (see
# `modules/systems/shared/brave-policies-data.nix`) at
# `/etc/brave/policies/managed/debrand.json`. Brave reads every JSON file
# under that directory at launch and applies the merged result as forced
# managed policies (visible at `chrome://policy`).
#
# Policies cannot be overridden from Brave's UI. Disabling this module or
# rebuilding without it removes the file and restores stock Brave defaults
# on next launch.
#
# Wired into the Linux Brave app façade
# (`modules/apps/linux/brave.nix`) — hosts that enable
# `custom.appBrave.enable` automatically get policies applied. Hosts
# normally do not flip `custom.sysBravePolicies.enable` directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/systems/nixos/brave-policies.nix ];
#   custom.sysBravePolicies.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysBravePolicies;
  policies = import ../shared/brave-policies-data.nix;
in
{
  options.custom.sysBravePolicies.enable = lib.mkEnableOption "Brave managed policies (debrand + privacy + force-installed extensions)";

  config = lib.mkIf cfg.enable {
    environment.etc."brave/policies/managed/debrand.json" = {
      text = builtins.toJSON policies;
      mode = "0444";
    };
  };
}
