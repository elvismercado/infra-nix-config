# Clone Hero — pinned upstream tarball, autoPatchelfHook'd, with .desktop entry
# https://clonehero.net  •  https://github.com/clonehero-game/releases
#
# Closed-source Unity game. We fetch the official Linux Standalone tarball
# from the GitHub release, patch its ELF interpreter + RUNPATH for NixOS,
# and install into the Nix store. User data (Songs, Custom, settings.ini,
# scores, profiles) lives at ~/.clonehero — game-managed, NOT part of this
# module.
#
# How to update:
#   1. Set custom.hmCloneHero.version to the new release tag (without the
#      leading 'v', e.g. "1.1.0.6085-final").
#   2. Compute the hash:
#        URL=https://github.com/clonehero-game/releases/releases/download/v<NEW>/Linux.x86_64-Standalone.tar
#        nix-prefetch-url "$URL"            # prints raw hash
#        nix hash to-sri --type sha256 <raw>
#      Set custom.hmCloneHero.hash to the sha256-... value.
#   3. Rebuild. If the game crashes on launch with a missing-lib error,
#      add the lib to buildInputs / postFixup --add-needed.
#
# Library list mirrors the nixpkgs `clonehero` derivation
# (pkgs/by-name/cl/clonehero/package.nix), known to work for the Unity
# Standalone build.
#
# Usage:
#   imports = [ ../../../modules/home-manager/linux/clonehero.nix ];
#   custom.hmCloneHero.enable = true;
#   custom.hmCloneHero.hash = "sha256-...";

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.hmCloneHero;

  # Wrap the upstream binary in a Nix derivation. Mirrors nixpkgs
  # clonehero (Unity Standalone) with the v1.1+ release URL pattern
  # (Linux.x86_64-Standalone.tar, no .xz).
  clonehero-pkg = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "clonehero";
    inherit (cfg) version;

    src = pkgs.fetchurl {
      url = "https://github.com/clonehero-game/releases/releases/download/v${finalAttrs.version}/${cfg.assetName}";
      inherit (cfg) hash;
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    buildInputs = with pkgs; [
      # Load-time libraries (DT_NEEDED in the ELF)
      alsa-lib
      gtk3
      (lib.getLib stdenv.cc.cc)
      zlib
      # Run-time libraries (dlopen'd) — listed as buildInputs so
      # autoPatchelfHook adds them to RUNPATH.
      dbus
      libGL
      xorg.libXcursor
      xorg.libXext
      xorg.libXi
      xorg.libXinerama
      libxkbcommon
      xorg.libXrandr
      xorg.libXScrnSaver
      xorg.libXxf86vm
      udev
      vulkan-loader
      wayland
    ];

    # Tarball may extract flat or into a single top-level directory.
    # Force sourceRoot=. and let installPhase locate the binary.
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      gameDir="."
      if [ ! -f clonehero ]; then
        candidate=$(find . -maxdepth 3 -type f -name clonehero -printf '%h\n' | head -n1)
        if [ -n "$candidate" ]; then
          gameDir="$candidate"
        else
          echo "clonehero binary not found in extracted tarball; layout:" >&2
          find . -maxdepth 3 >&2
          exit 1
        fi
      fi

      install -Dm755 "$gameDir/clonehero"      "$out/bin/clonehero"
      install -Dm644 "$gameDir/UnityPlayer.so" "$out/libexec/clonehero/UnityPlayer.so"

      mkdir -p "$out/share/clonehero"
      cp -r "$gameDir/clonehero_Data" "$out/share/clonehero/clonehero_Data"

      # Unity expects clonehero_Data and UnityPlayer.so to sit next to
      # the binary — symlink them into $out/bin.
      ln -s "$out/share/clonehero/clonehero_Data" "$out/bin/clonehero_Data"
      ln -s "$out/libexec/clonehero/UnityPlayer.so" "$out/bin/UnityPlayer.so"

      if [ -f "$out/share/clonehero/clonehero_Data/Resources/UnityPlayer.png" ]; then
        install -Dm644 \
          "$out/share/clonehero/clonehero_Data/Resources/UnityPlayer.png" \
          "$out/share/icons/hicolor/128x128/apps/clonehero.png"
      fi

      runHook postInstall
    '';

    # Some libs are dlopen'd from UnityPlayer.so without being in
    # DT_NEEDED. Force-link them so autoPatchelfHook resolves RUNPATH
    # (mirrors upstream nixpkgs derivation).
    postFixup = ''
      patchelf \
        --add-needed libasound.so.2 \
        --add-needed libdbus-1.so.3 \
        --add-needed libGL.so.1 \
        --add-needed libpthread.so.0 \
        --add-needed libudev.so.1 \
        --add-needed libvulkan.so.1 \
        --add-needed libwayland-client.so.0 \
        --add-needed libwayland-cursor.so.0 \
        --add-needed libwayland-egl.so.1 \
        --add-needed libX11.so.6 \
        --add-needed libXcursor.so.1 \
        --add-needed libXext.so.6 \
        --add-needed libXi.so.6 \
        --add-needed libXinerama.so.1 \
        --add-needed libxkbcommon.so.0 \
        --add-needed libXrandr.so.2 \
        --add-needed libXss.so.1 \
        --add-needed libXxf86vm.so.1 \
        "$out/libexec/clonehero/UnityPlayer.so"
    '';

    meta = with lib; {
      description = "Clone of Guitar Hero and Rockband-style games (pinned upstream tarball)";
      homepage = "https://clonehero.net";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  });
in
{
  options.custom.hmCloneHero = {
    enable = lib.mkEnableOption "Clone Hero rhythm game (pinned upstream tarball, .desktop entry)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "1.1.0.6085-final";
      example = "1.1.0.6085-final";
      description = ''
        Upstream release tag without the leading 'v'. Used both as the
        derivation version and to construct the GitHub download URL.
      '';
    };

    hash = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "sha256-xy7/3SDNgKw67ikA7CtRVK2gNrfjqx4cTDeRUkkSBKo=";
      description = ''
        SRI hash of the tarball. Compute with:
          nix-prefetch-url <URL>
          nix hash to-sri --type sha256 <raw-output>
      '';
    };

    assetName = lib.mkOption {
      type = lib.types.str;
      default = "Linux.x86_64-Standalone.tar";
      description = "Filename of the release asset to download.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.hash != "";
        message = ''
          custom.hmCloneHero.hash is required. Compute it with:
            nix-prefetch-url https://github.com/clonehero-game/releases/releases/download/v${cfg.version}/${cfg.assetName}
            nix hash to-sri --type sha256 <output>
        '';
      }
    ];

    home.packages = [ clonehero-pkg ];

    xdg.desktopEntries.clonehero = {
      name = "Clone Hero";
      genericName = "Rhythm Game";
      comment = "Clone of Guitar Hero and Rockband-style games";
      exec = "${clonehero-pkg}/bin/clonehero";
      icon = "clonehero";
      categories = [ "Game" ];
      type = "Application";
      terminal = false;
    };
  };
}
