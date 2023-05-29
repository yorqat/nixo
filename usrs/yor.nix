{
  lib,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./mods/hyprland
    ./mods/eww
    ./mods/neofetch
    ./mods/git
    ./mods/shell

    ./mods/apps/vscode
    ./mods/apps/neovim
    ./mods/apps/kitty
    ./mods/apps/firefox

    inputs.hyprland.homeManagerModules.default
  ];

  home = {
    username = "yor";
    homeDirectory = "/home/yor";

    stateVersion = "22.05";

    packages = with pkgs; [
      chromium # dev browser
      discord-canary # messenger
      gnome.nautilus
      prismlauncher # minecraft
      pavucontrol # audio device volume
      helvum # media routing
    ];
  };

  programs.home-manager.enable = true;

  # Enable automatic login for the user.
  # services.getty.autologinUser = "yor";
}
