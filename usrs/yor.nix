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
    ./mods/mpd

    ./mods/apps/vscode
    ./mods/apps/neovim
    ./mods/apps/kitty
    ./mods/apps/firefox

    inputs.hyprland.homeManagerModules.default
  ];

  # Symlink Home directories from Drives 
  systemd.user.tmpfiles.rules = [
    "L /home/yor/Documents - - - - /home/yor/mounts/state/Documents"
    "L /home/yor/Downloads - - - - /home/yor/mounts/state/Downloads"
    "L /home/yor/Videos - - - - /home/yor/mounts/state/Videos"
    "L /home/yor/Pictures - - - - /home/yor/mounts/state/Pictures"
    "L /home/yor/Music - - - - /home/yor/mounts/state/Music"

    "L /home/yor/.ssh - - - - /home/yor/Documents/.ssh"
  ];

  home = {
    username = "yor";
    homeDirectory = "/home/yor";

    stateVersion = "23.11";

    packages = with pkgs; [
      chromium # dev browser
      discord-canary # messenger
      signal-desktop # messenger
      gnome.nautilus
      prismlauncher # minecraft
      pavucontrol # audio device volume
      helvum # media routing
    ];
  };

  programs.home-manager.enable = true;
}
