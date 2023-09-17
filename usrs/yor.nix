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
    "L /home/yor/Documents - - - - /dat/Documents"
    "L /home/yor/Downloads - - - - /dat/Downloads"
    "L /home/yor/Videos - - - - /dat/Videos"
    "L /home/yor/Pictures - - - - /dat/Pictures"
    "L /home/yor/Music - - - - /dat/Music"

    # ssh credentials
    "L /home/yor/.ssh - - - - /cred/.ssh"
    # wakatime credentials
    "L /home/yor/.wakatime.cfg - - - - /cred/.wakatime.cfg"
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
