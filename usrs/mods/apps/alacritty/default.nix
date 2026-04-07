{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [alacritty tmux];
}
