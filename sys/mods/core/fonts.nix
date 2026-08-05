{pkgs, ...}: let
  satoshi = pkgs.stdenvNoCC.mkDerivation {
    pname = "satoshi";
    version = "2.000";

    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/satoshi";
      hash = "sha256-TEa7Og5gKyxSobVZMlz5GS2NLTh4OqZf6WQF/OTgQUg=";
      extension = "zip";
      stripRoot = false;
    };

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm644 -t $out/share/fonts/opentype/satoshi Satoshi_Complete/Fonts/OTF/*.otf
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Satoshi font family, fetched from Fontshare at build time";
      homepage = "https://www.fontshare.com/fonts/satoshi";
      license = licenses.unfree; # Fontshare license, not OFL/redistributable
      platforms = platforms.all;
    };
  };
in {
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.droid-sans-mono
      inter
      comic-mono
      comic-neue
      fira-code
      satoshi
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = ["Comic Neue"];
        monospace = ["Comic Mono" "DroidSansMono Nerd Font"];
      };
    };
  };
}
