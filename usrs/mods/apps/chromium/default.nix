{
  pkgs,
  lib,
  ...
}: let 
  adnauseam = pkgs.stdenv.mkDerivation rec {
    pname = "adnauseam";
    version = "3.28.6"; # Check GitHub for the latest release tag

    src = pkgs.fetchurl {
      url = "https://github.com/dhowe/AdNauseam/releases/download/v${version}/adnauseam-${version}.chromium.zip";
      # Swap this with the actual SHA-256 hash or use lib.fakeHash to get it
      hash = "sha256-uLp50pAaEYZbTQD7E4KffuSFqBqz6hjE3ZJdY/5nbn8=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      unzip $src -d temp_out
    '';

    installPhase = ''
      mkdir -p $out
      # Copy the specific extension subfolder to the output path
      cp -r temp_out/adnauseam.chromium/* $out/
    '';
  };
in {
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;

    commandLineArgs = [
      "--disable-features=ExtensionManifestV2Unsupported"
      "--load-extension=${adnauseam}"
    ];
  };
}
