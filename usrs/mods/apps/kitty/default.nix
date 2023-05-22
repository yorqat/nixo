{
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.kitty];
  xdg.configFile."kitty".source = ./config;
}
