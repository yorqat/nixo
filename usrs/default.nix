{
  lib,
  inputs,
  pkgs,
  ...
}: let
  # Define your local variables here
  setup = import ../setup;

  createTmpfilesRules = rules: let
    # Define a helper function to format each pair of strings as a tmpfiles rule
    formatRule = rulePair: "L ${builtins.elemAt rulePair 0} - - - - ${builtins.elemAt rulePair 1}";
  in
    # Map each pair of strings to the desired format using `formatRule`
    map formatRule rules;

  includeLibreOffice = lib.optional setup.includes.libreoffice pkgs.libreoffice-fresh;
  includePrismMinecraft = lib.optional setup.includes.minecraftPrismLauncher pkgs.prismlauncher;
in {
  imports = [
    # niri works alongside the nixos module
    ./mods/niri
    ./mods/eww
    ./mods/neofetch
    ./mods/git
    ./mods/shell
    ./mods/mpd

    # ./mods/apps/vscode
    ./mods/apps/neovim
    ./mods/apps/kitty
    ./mods/apps/chromium
    ./mods/apps/mpv

    inputs.nix4nvchad.homeManagerModules.default
    inputs.nixvim.homeModules.nixvim
  ];

  # Symlink Home directories from Drives
  systemd.user.tmpfiles.rules = createTmpfilesRules setup.symLinks;

  home = {
    username = setup.userName;
    homeDirectory = setup.homeDir;
    stateVersion = setup.homeManagerVersion;

    packages = with pkgs;
      [
        deluge-gtk # torrent client
        discord-canary # messenger
        signal-desktop # messenger
        nautilus # file explorer
        pavucontrol # audio device volume
        # helvum # media routing
        crosspipe
        sonixd # music player
        blender
        dolphin-emu
      ]
      ++ includeLibreOffice ++ includePrismMinecraft;
  };

  programs.home-manager.enable = true;

  # near-instant theme toggle: both palettes are pre-built, switching is
  # just running the specialisation's activation script (no rebuild needed)
  specialisation.light.configuration = {
    stylix.polarity = lib.mkForce "light";
    stylix.base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
  };
}
