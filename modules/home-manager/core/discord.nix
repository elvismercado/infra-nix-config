# Discord client — shared cross-platform core
#
# Declares the `custom.hmDiscord.enable` toggle. The option is named after
# the *concept* (Discord client) rather than any specific binary; wrappers
# choose the implementation per OS.
#
# Binary policy: prefer **Vesktop** (open-source Discord client with Vencord
# built-in and native screen-share audio on Wayland/PipeWire) wherever a
# vesktop package or cask is available. Fall back to the upstream Discord
# binary only on platforms where vesktop is unavailable.
#
# Today:
#   - Linux wrapper:  installs `pkgs.vesktop` (vesktop available in nixpkgs).
#   - Darwin wrapper: empty config — the Homebrew cask `vesktop` provides
#                     the binary (vesktop available on Homebrew).
# So vesktop is used on every supported OS today; the discord fallback is
# documented for future-proofing only and is not exercised.
#
# Internal — do not import from hosts. Imported by `linux/discord.nix` and
# `darwin/discord.nix`. In normal use, hosts wire Discord through the
# Option 3 app façade `modules/apps/{linux,darwin}/discord.nix`.

{ lib, ... }:

{
  options.custom.hmDiscord.enable = lib.mkEnableOption "Discord client (vesktop preferred — Linux: nixpkgs; Darwin: Homebrew cask)";
}
