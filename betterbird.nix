{
  lib,
  buildMozillaMach,
  fetchFromGitHub,
  fetchurl,
  git,
  thunderbirdPackages,
}:

let
  thunderbird-unwrapped = thunderbirdPackages.thunderbird-153;

  version = "153.6.0esr";
  majVer = lib.versions.major version;

  betterbird-patches = fetchFromGitHub {
    owner = "Betterbird";
    repo = "thunderbird-patches";
    rev = "${version}-bb12";
    hash = "sha256-cdo2DLyRdJmw1QZZ3R30h0BwoI6u6aWMABDc9SXObLw=";
  };

  betterbird-mach = buildMozillaMach {
    pname = "betterbird";
    inherit version;

    applicationName = "Betterbird";
    binaryName = "betterbird";
    branding = "comm/mail/branding/betterbird";
    inherit (thunderbird-unwrapped) application extraPatches;

    src = fetchurl {
      url = "https://archive.mozilla.org/pub/thunderbird/candidates/153.6.0esr-candidates/build1/source/thunderbird-153.6.0esr.source.tar.xz";
      sha512 = "sha512-F9YcmBF8QZkufQUsEj8KxENBCYNmRSjLVg3IJCFnfx920LBHPvD6db5Hh3adIhgCXXsnq999tuJwAEI29l+ryA==";
    };

    extraPostPatch =
      thunderbird-unwrapped.extraPostPatch or ""
      + /* bash */ ''
        PATH=$PATH:${lib.makeBinPath [ git ]}
        patches=$(mktemp -d)
        for dir in branding bugs cherrypicks external features misc; do
          cp -r ${betterbird-patches}/${majVer}/$dir $patches/ 2>/dev/null || true
        done
        cp ${betterbird-patches}/${majVer}/series* $patches/
        chmod -R +w $patches

        chmod -R +w dom/base/test/gtest/

        while read patch; do
          patch="''${patch%%#*}"
          patch=$(echo "$patch" | xargs)
          if [[ $patch == "" ]]; then
            continue
          fi

          # requires vendored icu, fails to link with our icu
          # feature-506064 depends on those icu patches
          if [[ $patch == *14-feature-regexp-searchterm.patch || $patch == *14-feature-regexp-searchterm-moz.patch || $patch == *feature-506064-match-diacritics.patch || $patch == *feature-506064-match-diacritics-moz.patch ]]; then
            continue
          fi

          echo Applying patch $patch.
          if [[ $patch == *-moz.patch ]]; then
            git apply -p1 -v < $patches/$patch
          else
            cd comm
            git apply -p1 -v < $patches/$patch
            cd ..
          fi
        done < <(cat $patches/series $patches/series-moz)

        # Fix MOZ_APP_NAME conflict: comm/mail/moz.configure implies "thunderbird"
        # but buildMozillaMach passes --with-app-name=betterbird
        substituteInPlace comm/mail/moz.configure \
          --replace-fail 'imply_option("MOZ_APP_NAME", "thunderbird")' 'imply_option("MOZ_APP_NAME", "betterbird")'
      '';

    meta = {
      description = "Betterbird is a fine-tuned version of Mozilla Thunderbird, Thunderbird on steroids, if you will";
      homepage = "https://www.betterbird.eu/";
      mainProgram = "betterbird";
      maintainers = with lib.maintainers; [ ];
      platforms = thunderbird-unwrapped.meta.platforms;
      license = thunderbird-unwrapped.meta.license;
      broken = thunderbird-unwrapped.meta.broken or false;
    };
  };

  betterbird-with-flags = betterbird-mach.override {
    enableCrashReporter = false; # not supported
    enableLocation = false;
    enableWebRTC = false;
    enablePGO = false; # console.warn: feeds: "downloadFeed: network connection unavailable"
  };
in
betterbird-with-flags.overrideAttrs (oldAttrs: {
  postInstall =
    oldAttrs.postInstall or ""
    + ''
      if [ -d "$out/lib/thunderbird" ]; then
        mv $out/lib/thunderbird/* $out/lib/betterbird/
        rmdir $out/lib/thunderbird/
        rm $out/bin/thunderbird
        ln -srf $out/lib/betterbird/betterbird $out/bin/betterbird
      fi
    '';

  doInstallCheck = false;

  passthru = oldAttrs.passthru or { } // {
    inherit betterbird-patches;
  };
})