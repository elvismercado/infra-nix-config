# Cross-host metadata for EDGE (2018 Intel MacBook Pro).
#
# Consumed by other hosts (and shared loaders) — distinct from
# `user-settings.nix` which feeds this host's own build. See
# `flake/metadata.nix` for the loader and consumers like
# `modules/home-manager/all/syncthing-peers.nix`.
#
# Multiple LAN addresses reflect the various physical interfaces in
# rotation (built-in wifi, USB ethernet, dock ethernet, …). Syncthing
# tries them in order, then falls back to global discovery (`dynamic`)
# when the laptop is off-LAN.
{
  hostname = "EDGE";
  managed = true;
  os = "darwin";
  lanIp = "192.168.1.50";

  syncthing = {
    id = "57HA3EL-W4S5WXA-DNAA5TN-PPRF6QQ-T2SFPKC-FTFLUXF-FYTZOMZ-LYNOMAX";
    addresses = [
      "tcp://192.168.1.50:22000"
      "tcp://192.168.1.51:22000"
      "tcp://192.168.1.52:22000"
      "dynamic"
    ];
  };
}
