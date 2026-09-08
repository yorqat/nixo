{
  pkgs,
  lib,
  ...
}: let
  adnauseam = pkgs.stdenv.mkDerivation rec {
    pname = "adnauseam";
    version = "3.28.8";

    src = pkgs.fetchurl {
      url = "https://github.com/dhowe/AdNauseam/releases/download/v${version}/adnauseam-${version}.chromium.zip";
      hash = "sha256-CUZOsOvmYtWWz7z1dscIq/8T5N0AjiqAg+nbXTL32+c=";
    };

    nativeBuildInputs = [pkgs.unzip];

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
      "--use-angle=vulkan"
    ];
  };
}
