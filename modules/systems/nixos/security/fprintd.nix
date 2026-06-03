# fprintd — fingerprint reader support
#
# Enables the fprintd daemon. Once a fingerprint is enrolled
# (`fprintd-enroll`), it can be used for login, sudo, and polkit prompts.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/security/fprintd.nix ];
#   custom.sysNixFprintd.enable = true;

{
  config,
  lib,
  ...
}:

{
  options = {
    custom.sysNixFprintd.enable = lib.mkEnableOption "fprintd fingerprint reader daemon (login, sudo, and polkit)";
  };

  config = lib.mkIf config.custom.sysNixFprintd.enable {
    services.fprintd.enable = true;

    # Enroll fingerprints with: fprintd-enroll
    # Verify with: fprintd-verify
    # Once enrolled, fingerprint auth works for login, sudo, and polkit prompts
  };
}
