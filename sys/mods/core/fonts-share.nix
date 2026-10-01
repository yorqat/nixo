# Fontshare packages shared by fonts.nix and stylix.nix (AUDIT 4.1).
# Not a NixOS module: import it as `import ./fonts-share.nix {inherit pkgs;}`.
{pkgs}: let
  lib = pkgs.lib;
in {
  satoshi = pkgs.stdenvNoCC.mkDerivation {
    pname = "satoshi";
    version = "2.000";

    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/satoshi";
      hash = "sha256-z5KM+IH4234HCzkE/nZn9fg+vADXUlcddCoHsO06t0w=";
      extension = "zip";
      stripRoot = false;
    };

    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm644 -t $out/share/fonts/opentype/satoshi Satoshi_Complete/Fonts/OTF/*.otf
      runHook postInstall
    '';

    meta = {
      description = "Satoshi font family, fetched from Fontshare at build time";
      homepage = "https://www.fontshare.com/fonts/satoshi";
      license = lib.licenses.unfree; # Fontshare license, not OFL/redistributable
      platforms = lib.platforms.all;
    };
  };

  sentient = pkgs.stdenvNoCC.mkDerivation {
    pname = "sentient-font";
    version = "1.0";

    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/sentient";
      hash = "sha256-z+d9/9E+qzz8bwT9gYE3CBpkyoD5pQwy8y5iIsR0bKo=";
      extension = "zip";
    };

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp Fonts/OTF/*.otf $out/share/fonts/opentype/
    '';

    meta = {
      description = "Sentient font family, fetched from Fontshare at build time";
      homepage = "https://www.fontshare.com/fonts/sentient";
      license = lib.licenses.unfree; # Fontshare license, not OFL/redistributable
      platforms = lib.platforms.all;
    };
  };
}
