{
  pkgs,
  lib,
  ...
}: {
  home.packages = [ pkgs.neofetch ];
  xdg.configFile."neofetch".source = ./config;
}
