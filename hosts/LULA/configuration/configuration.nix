# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ ... }:

{
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Set at first install of the system; do not
  # bump just because the channel moves forward — see configuration.nix(5).
  system.stateVersion = "25.11";
}
