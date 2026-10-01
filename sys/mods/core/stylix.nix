{
  pkgs,
  lib,
  ...
}: let
  wallpaper = ../../../usrs/mods/eww/config/images/wallpapers/home.jpg;
  fontshare = import ./fonts-share.nix {inherit pkgs;};
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
        package = fontshare.sentient;
        name = "Sentient";
      };
      sansSerif = {
        package = fontshare.satoshi;
        name = "Satoshi";
      };
      monospace = {
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
