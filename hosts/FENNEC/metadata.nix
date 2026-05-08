# Cross-host metadata for FENNEC (Linux side of the dual-boot box).
#
# Consumed by other hosts (and shared loaders) — distinct from
# `user-settings.nix` which feeds this host's own build. See
# `flake/metadata.nix` for the loader and consumers like
# `modules/home-manager/all/syncthing-peers.nix`.
#
# NOTE: The Windows side of the same physical machine is its own peer
# with a separate device ID — see `hosts/FENNEC-windows/metadata.nix`.
{
  hostname = "FENNEC";
  managed = true;
  os = "nixos";
  lanIp = "192.168.20.40";

  syncthing = {
    id = "OPSABBX-JQBGPE4-BQLMY7I-SWU7RUC-NHBKVG7-5HOTYIG-YOJQ23Q-XM5ZYAB";
    addresses = [
      "tcp://192.168.20.40:22000"
      "dynamic"
    ];
  };
}
