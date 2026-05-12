# Brave managed policies — Darwin writer
#
# Applies the shared policy attrset (see
# `modules/systems/shared/brave-policies-data.nix`) to Brave on macOS via
# `system.defaults.CustomUserPreferences."com.brave.Browser"`. nix-darwin
# handles plist serialization. Brave reads the preferences domain at launch
# and applies the keys as forced managed policies (visible at
# `chrome://policy`).
#
# If Brave is running during `darwin-rebuild switch`, restart Brave for new
# policy values to take effect — same caveat as any plist-driven app.
#
# Wired into the darwin Brave app façade
# (`modules/apps/darwin/brave.nix`) — hosts that enable
# `custom.appBrave.enable` automatically get policies applied. Hosts
# normally do not flip `custom.sysBravePolicies.enable` directly.
#
# Usage (rare — prefer the app façade):
#   imports = [ ../../../modules/systems/darwin/brave-policies.nix ];
#   custom.sysBravePolicies.enable = true;

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysBravePolicies;
  policies = import ../shared/brave-policies-data.nix { extensions = cfg.extensions; };
in
{
  options.custom.sysBravePolicies = {
    enable = lib.mkEnableOption "Brave managed policies (debrand + privacy + force-installed extensions)";

    extensions = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        Chrome Web Store extension IDs to force-install. `null` (default)
        inherits the shared list from `brave-policies-data.nix`. Pass `[]`
        to disable force-install entirely on this host. Hosts normally set
        this via `custom.appBrave.extensions` on the Brave app façade.
      '';
      example = [ "nngceckbapebfimnlniiiahkandclblb" ];
    };
  };

  config = lib.mkIf cfg.enable {
    system.defaults.CustomUserPreferences."com.brave.Browser" = policies;
  };
}
