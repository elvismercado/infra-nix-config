# Webcamoid — cross-platform webcam capture suite
#
# Qt6 video-capture studio: photos/videos, 60+ effects, virtual webcam,
# desktop capture. Used as the general-purpose camera viewer/tweaker on
# Linux (covers what cameractrls did, plus capture and effects).
#
# Linux-only for now: upstream has no maintained macOS binary (no
# Homebrew cask exists and the developer is crowdfunding macOS release
# work — https://webcamoid.github.io/). When a maintained cask lands,
# promote this to an `appWebcamoid` cross-layer façade.
#
# On EDGE the equivalent role is filled by Logitech G HUB (StreamCam
# tuning) plus macOS's built-in camera tooling.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/webcamoid.nix ];
#   custom.hmWebcamoid.enable = true;

{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.custom.hmWebcamoid.enable =
    lib.mkEnableOption "Webcamoid (Linux webcam capture suite — viewer, recorder, effects, virtual cam)";

  config = lib.mkIf config.custom.hmWebcamoid.enable {
    home.packages = [ pkgs.webcamoid ];
  };
}
