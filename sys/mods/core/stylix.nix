{
  pkgs,
  lib,
  ...
}: let
  wallpaper = ../../../usrs/mods/eww/config/images/wallpapers/home.jpg;

  satoshi = pkgs.stdenvNoCC.mkDerivation {
    pname = "satoshi-font";
    version = "1.0";
    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/satoshi";
      sha256 = "sha256-74/1mRqgA1WAXwNxUI9AIdPFhRpKASnl1qEkWVjaIG0=";
      extension = "zip";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp Fonts/OTF/*.otf $out/share/fonts/opentype/
    '';
  };

  sentient = pkgs.stdenvNoCC.mkDerivation {
    pname = "sentient-font";
    version = "1.0";
    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/sentient";
      sha256 = "sha256-z+d9/9E+qzz8bwT9gYE3CBpkyoD5pQwy8y5iIsR0bKo=";
      extension = "zip";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp Fonts/OTF/*.otf $out/share/fonts/opentype/
    '';
  };

  azeret-mono = pkgs.stdenvNoCC.mkDerivation {
    pname = "azeret-mono-font";
    version = "1.0";
    src = pkgs.fetchzip {
      url = "https://api.fontshare.com/v2/fonts/download/azeret-mono";
      sha256 = "sha256-iwuOg9D7BJV03IG+vk1RM70fPPpARy0eAYF0z1oMvgw=";
      extension = "zip";
    };
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp Fonts/OTF/*.otf $out/share/fonts/opentype/
    '';
  };
in {
  stylix = {
    enable = true;
    image = wallpaper;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    cursor = {
      package = pkgs.qogir-icon-theme;
      name = "Qogir-Light";
      size = 24;
    };

    fonts = {
      serif = {
        package = sentient;
        name = "Sentient";
      };
      sansSerif = {
        package = satoshi;
        name = "Satoshi";
      };
      monospace = {
        # package = azeret-mono;
        # name = "Azeret Mono";

        package = pkgs.comic-mono;
        name = "Comic Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
