{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [kitty tmux];
  xdg.configFile."kitty".source = ./config;
}
