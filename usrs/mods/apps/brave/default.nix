{pkgs, ...}: let
  # Full uBlock Origin (MV2 engine). Stock Chromium 151 removed MV2 support
  # (verified: the extension-manifest-v2 feature is gone from its binary), so
  # this only loads under Brave, which keeps MV2 alive on the same base.
  ublockOrigin = pkgs.stdenv.mkDerivation rec {
    pname = "ublock-origin";
    version = "1.75.0";

    src = pkgs.fetchurl {
      url = "https://github.com/gorhill/uBlock/releases/download/${version}/uBlock0_${version}.chromium.zip";
      hash = "sha256-OTz5VwnRB01AIpcOkBTkNDlcU6giOH8eJfQ76Xz0tYI=";
    };

    nativeBuildInputs = [pkgs.unzip];

    unpackPhase = ''
      unzip $src -d temp_out
    '';

    installPhase = ''
      mkdir -p $out
      cp -r temp_out/uBlock0.chromium/* $out/
    '';
  };
in {
  home.packages = [
    (pkgs.brave.override {
      # Sideload the unpacked blocker: the Chrome Web Store no longer serves the
      # MV2 package, so this is the only reliable path. Expect a one-time
      # "unsupported command-line flag" bar; uBlock itself loads fine.
      commandLineArgs = "--load-extension=${ublockOrigin}";
    })
  ];
}
