{
  lib,
  inputs,
  pkgs,
  setup,
  ...
}: let
  createTmpfilesRules = rules: let
    formatRule = rulePair: "L ${builtins.elemAt rulePair 0} - - - - ${builtins.elemAt rulePair 1}";
  in
    map formatRule rules;

  includeLibreOffice = lib.optional setup.includes.libreoffice pkgs.libreoffice-fresh;
  includePrismMinecraft = lib.optional setup.includes.minecraftPrismLauncher pkgs.prismlauncher;
in {
  imports = [
    # niri works alongside the nixos module
    ./mods/niri
    ./mods/eww
    ./mods/fastfetch
    ./mods/git
    ./mods/shell
    ./mods/mpd

    # ./mods/apps/vscode
    ./mods/apps/neovim
    ./mods/apps/opencode
    ./mods/apps/kitty
    ./mods/apps/brave
    ./mods/apps/chromium-guest
    ./mods/apps/mpv

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
        crosspipe
        sonixd # music player
      ]
      ++ includeLibreOffice ++ includePrismMinecraft;
  };

  programs.home-manager.enable = true;

  # both default to true upstream and emit config dirs, autostart entries and
  # (for kde) an activation step hunting for plasma-apply-*. we run niri only;
  # the qt/gtk targets are what actually theme the apps we have.
  stylix.targets = {
    kde.enable = false;
    gnome.enable = false;
  };

  # near-instant theme toggle: both palettes are pre-built, switching is
  # just running the specialisation's activation script (no rebuild needed)
  specialisation.light.configuration = {
    stylix.polarity = lib.mkForce "light";
    stylix.base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
  };

  stylix.icons = {
    enable = true;
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };
}
