{
  lib,
  inputs,
  pkgs,
  ...
}: let
  # Define your local variables here
  setup = import ../setup;

  includeLibreOffice = lib.optional setup.includes.libreoffice pkgs.libreoffice-fresh;
  includePrismMinecraft = lib.optional setup.includes.minecraftPrismLauncher pkgs.prismlauncher;
in {
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
    username = "${setup.userName}";
    homeDirectory = "/home/${setup.userName}";

    stateVersion = "23.11";

    packages = with pkgs; [
      chromium # dev browser
      discord-canary # messenger
      signal-desktop # messenger
      gnome.nautilus # file explorer
      pavucontrol # audio device volume
      helvum # media routing
      sonixd
    ] ++ includeLibreOffice ++ includePrismMinecraft;
  };

  programs.home-manager.enable = true;
}
