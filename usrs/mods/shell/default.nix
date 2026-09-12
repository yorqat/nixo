{pkgs, ...}: {
  home.sessionVariables.EDITOR = "nvim";

  home.packages = with pkgs; [
    tmux
    lua
    libimobiledevice
    imagemagick
    ffmpeg_6-full
    wget
  ];

  programs = {
    bash = {
      enable = true;
      # env vars rendered by sops-nix (sys/mods/core/secrets.nix)
      bashrcExtra = ''
        [ -r "$HOME/.config/secrets/env" ] && . "$HOME/.config/secrets/env"
      '';
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
  };
}
