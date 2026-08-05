{ pkgs, ... }: {
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
    bash.enable = true;

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
