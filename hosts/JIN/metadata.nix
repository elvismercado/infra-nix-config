# Cross-host metadata for JIN.
#
# Consumed by other hosts (and shared loaders) — distinct from
# `user-settings.nix` which feeds this host's own build. See
# `flake/metadata.nix` for the loader and consumers like
# `modules/home-manager/all/syncthing-peers.nix`.
{
  hostname = "JIN";
  managed = true;
  os = "nixos";
  lanIp = "192.168.1.10";

  syncthing = {
    # TODO: capture from Web UI → Actions → Show ID
    # id = "...";
    addresses = [
      "tcp://192.168.1.10:22000"
      "dynamic"
    ];
  };
}
