# fprintd — fingerprint reader support
#
# Enables the fprintd daemon. Once a fingerprint is enrolled
# (`fprintd-enroll`), it can be used for login, sudo, and polkit prompts.
#
# Usage:
#   imports = [ ../../../modules/systems/nixos/security/fprintd.nix ];
#   custom.sysNixFprintd.enable = true;
#   # optional, default true:
#   custom.sysNixFprintd.loginGreeter.enable = false;  # disable swipe at SDDM only

{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.sysNixFprintd;
in
{
  options.custom.sysNixFprintd = {
    enable = lib.mkEnableOption "fprintd fingerprint reader daemon (login, sudo, and polkit)";

    loginGreeter.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When `false`, fingerprint auth is disabled at the SDDM login
        greeter only. Sudo, polkit, and the Plasma lock screen still
        use fprintd. Use on hosts where the greeter does not surface
        the "place finger" pam_conv prompt - users then get a
        predictable password-only login and fingerprint becomes a
        post-login convenience for sudo / unlock.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.fprintd.enable = true;

    # SDDM's password greeter swallows pam_conv info messages, so the
    # "place finger on reader" prompt never reaches the user. With
    # pam_fprintd as `sufficient` ahead of pam_unix, the typed password
    # is effectively ignored while the conv loop blocks on the sensor.
    # Opt-out turns fingerprint off for the greeter only.
    security.pam.services.sddm.fprintAuth = lib.mkIf (!cfg.loginGreeter.enable) false;
  };
}
