# Cross-host metadata for LULA (Lenovo ThinkPad T14 Gen 2 — Intel i5-1135G7).
#
# Personal laptop for a non-technical user. Not part of the Syncthing
# mesh, so no entry exists in the sibling `nix-config-private` repo
# either.
#
# TEMPORARY: `os = "darwin"` until Round 2 of the NixOS migration is
# complete. The hardware has changed (was a 2026 MacBook Neo, now a
# Lenovo T14 Gen 2 / x86_64-linux), but this host's `configuration/`
# and `home-manager/` are still macOS-shaped. Flipping `os` to `"nixos"`
# now would break flake evaluation. The flip happens alongside the
# configuration rewrite. See hosts/LULA/README.md (Status section) and
# the LULA NixOS migration tasks in TODO.md.
{
  hostname = "LULA";
  managed = true;
  os = "darwin";
}
