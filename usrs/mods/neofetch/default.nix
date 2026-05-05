{
  pkgs,
  lib,
  ...
}: {
  home.packages = [pkgs.fastfetch];
  xdg.configFile."fastfetch".source = ./config;
}
