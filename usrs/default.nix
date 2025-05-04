{
  lib,
  inputs,
  pkgs,
  ...
}: let
  # Define your local variables here
  setup = import ../setup;

  createTmpfilesRules = rules:
    let
      # Define a helper function to format each pair of strings as a tmpfiles rule
      formatRule = rulePair:
        "L ${builtins.elemAt rulePair 0} - - - - ${builtins.elemAt rulePair 1}";
    in
      # Map each pair of strings to the desired format using `formatRule`
      map formatRule rules;

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
  systemd.user.tmpfiles.rules = createTmpfilesRules setup.symLinks;

  home = {
    username = setup.userName;
    homeDirectory = setup.homeDir;
    stateVersion = setup.stateVersion;

    packages = with pkgs; [
      chromium # dev browser
      discord-canary # messenger
      signal-desktop # messenger
      gnome.nautilus # file explorer
      pavucontrol # audio device volume
      helvum # media routing
      sonixd # music player

      jump # change directory changes
    ] ++ includeLibreOffice ++ includePrismMinecraft;
  };

  programs.home-manager.enable = true;
}
