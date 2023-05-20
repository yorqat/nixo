{ lib, inputs, pkgs, ... }:
{
  imports = [
    ./mods/hyprland
    ./mods/eww
    ./mods/neofetch
    ./mods/git
    ./mods/shell

    ./mods/apps/vscode
    ./mods/apps/neovim
    ./mods/apps/kitty

    inputs.hyprland.homeManagerModules.default
  ];

  home = {
    username = "yoru";
    homeDirectory = "/home/yoru";

    stateVersion = "22.05";

    packages = with pkgs; [ chromium discord-canary flameshot swaybg ];
  };

  programs.home-manager.enable = true;

  # Enable automatic login for the user.
  # services.getty.autologinUser = "yoru";
}
