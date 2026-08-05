{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [kitty];
  xdg.configFile."kitty".source = ./config;
}
