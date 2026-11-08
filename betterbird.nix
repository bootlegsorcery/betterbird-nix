{
  lib,
  stdenv,
  fetchurl,
  wrapGAppsHook3,
  autoPatchelfHook,
  patchelfUnstable,
  alsa-lib,
  gtk3,
}:

let
  version = "153.6.0esr-bb12";

  sources = {
    x86_64-linux = {
      url = "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-153.6.0esr-bb12.en-US.linux-x86_64.tar.xz";
      hash = "sha256-nYC2s0Jcl9k87qutPy3gxyLg/QVTHY0to0SVhqhV9B8=";
    };
    aarch64-linux = {
      url = "https://www.betterbird.eu/downloads/LinuxArchive/betterbird-153-linux-aarch64-built-with-glibc-2_36/betterbird-153.6.0esr-bb12.en-US.linux-aarch64.tar.xz";
      hash = "sha256-t4rzmXuyjSkQQP+I1vRnVg2wylLIcZU6WvGap3+qTzg=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "betterbird-unwrapped";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [
    wrapGAppsHook3
    autoPatchelfHook
    patchelfUnstable
  ];

  buildInputs = [ alsa-lib ];

  # Betterbird uses Mozilla's relrhack to process relocations from a fixed offset.
  patchelfFlags = [ "--no-clobber-old-sections" ];

  postPatch = ''
    # Updates are managed by Nix so the immutable installation is never modified.
    echo 'pref("app.update.auto", "false");' >> defaults/pref/channel-prefs.js
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$prefix/usr/lib/betterbird"
    cp -r . "$prefix/usr/lib/betterbird"

    mkdir -p "$out/bin"
    ln -s "$prefix/usr/lib/betterbird/betterbird" "$out/bin/betterbird"

    # wrapThunderbird expects the application under $out/lib.
    ln -s "$out/usr/lib" "$out/lib"
    gappsWrapperArgs+=(--argv0 "$out/bin/.betterbird-wrapped")

    runHook postInstall
  '';

  passthru = {
    applicationName = "Betterbird";
    binaryName = "betterbird";
    inherit gtk3;
    withFFmpeg = true;
    withGSSAPI = true;
  };

  meta = {
    description = "Betterbird, a fine-tuned version of Mozilla Thunderbird (official binary)";
    homepage = "https://www.betterbird.eu/";
    mainProgram = "betterbird";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.mpl20;
    platforms = builtins.attrNames sources;
    hydraPlatforms = [ ];
  };
}
