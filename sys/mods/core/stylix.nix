{pkgs, ...}: let
  wallpaper = ../../../usrs/mods/eww/config/images/wallpapers/home.jpg;
in {
  stylix = {
    enable = true;
    image = wallpaper;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    cursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
    };

    fonts = {
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      sansSerif = {
        package = pkgs.comic-neue;
        name = "Comic Neue";
      };
      monospace = {
        package = pkgs.nerd-fonts.droid-sans-mono;
        name = "DroidSansMono Nerd Font";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
