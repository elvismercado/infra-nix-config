# Manage dotfiles and user packages

{
  ...
}:

{
  imports = [
    # Host
    ./home.nix

    # Base
    ../../../modules/home-manager/all/base.nix

    # Shell
    ../../../modules/home-manager/all/aliases.nix
    ../../../modules/home-manager/all/bash.nix
    ../../../modules/home-manager/all/fastfetch.nix
    ../../../modules/home-manager/all/git.nix
    ../../../modules/home-manager/all/ssh.nix
    ../../../modules/home-manager/all/starship.nix

    # Linux
    ../../../modules/home-manager/linux/aliases.nix
    ../../../modules/home-manager/linux/nixos-diagnostics.nix
    ../../../modules/home-manager/linux/plasma/lula.nix
    ../../../modules/home-manager/linux/autostart.nix
    ../../../modules/home-manager/linux/trayscale.nix
  ];

  # Base
  custom.hmBase.enable = true;

  # Shell
  custom.hmAliases.enable = true;
  custom.hmBash.enable = true;
  custom.hmFastfetch.enable = true;
  custom.hmGit.enable = true;
  custom.hmSsh.enable = true;
  custom.hmStarship.enable = true;
  custom.hmStarship.style = "pastel-powerline";

  # Linux
  custom.hmLinuxAliases.enable = true;
  custom.hmNixosDiagnostics.enable = true;

  # Tailscale tray icon (Trayscale) — starts minimised to the system tray
  # on login so remote support over the tailnet is one click away.
  custom.hmTrayscale.enable = true;
  custom.hmAutostart.enable = true;
  custom.hmAutostart.entries.trayscale = {
    name = "Trayscale";
    exec = "trayscale --hide-window";
    icon = "dev.deltadev.trayscale";
  };

  # Linux / KDE Plasma — LULA layout (top tray panel + bottom dock,
  # no Global Menu). Weather widget pulls from the private overlay's
  # userSettings.weatherLocation. Hot corners disabled to avoid
  # accidental Overview triggers.
  custom.hmPlasmaLula.enable = true;
  custom.hmPlasmaCommon.hotCorners.enable = false;
  custom.hmPlasmaCommon.kwallet.enable = false;
  # Double-click to open files/folders (Windows / macOS Finder behavior).
  custom.hmPlasmaCommon.singleClickToOpen = false;
  # Larger 36px Breeze_Snow cursor with bouncing click-feedback pulse.
  custom.hmPlasmaCommon.cursor.enable = true;
  # Confirm before logout / restart / shutdown.
  custom.hmPlasmaCommon.confirmLogout.enable = true;
  # Dolphin preset for non-technical users: full path in title, status
  # bar, tooltips, archives-as-folders, file-picker defaults to
  # Details view, externally-opened folders reuse an existing window.
  custom.hmPlasmaCommon.dolphin.enable = true;

  # Unbind Meta+arrow quick-tile shortcuts (accidental-trigger surface
  # when the Meta key gets bumped during typing). Drag-to-edge snapping
  # stays enabled so the user can discover and learn the gesture
  # organically.
  custom.hmPlasmaCommon.quickTile.shortcuts.enable = false;

  # Klipper — keep clipboard history short. Limits the privacy /
  # confusion footprint of "the last 20 things you copied are visible
  # in the system tray" (Bitwarden passwords, Wi-Fi PSKs, addresses).
  # Five entries is enough for practical clipboard reuse without
  # turning the popup into a scrolling history.
  programs.plasma.configFile."klipperrc"."General" = {
    MaxClipItems = 5;
    KeepClipboardContents = true;
  };

  # Trackpad — per-device libinput config. Plasma Wayland reads
  # `~/.config/kcminputrc`; identifiers come from
  # `/proc/bus/input/devices` on LULA:
  #   SynPS/2 Synaptics TouchPad, Vendor=0002, Product=0007.
  programs.plasma.input.touchpads = [
    {
      enable = true;
      name = "SynPS/2 Synaptics TouchPad";
      vendorId = "0002";
      productId = "0007";
      naturalScroll = true;
      tapToClick = true;
      disableWhileTyping = true;
    }
  ];
}
