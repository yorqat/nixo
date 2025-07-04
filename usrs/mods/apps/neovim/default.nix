{pkgs, ...}: {
  programs.neovim = {
    enable = false;
    extraConfig = ''
      set number relativenumber
    '';
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;

    plugins = [
      pkgs.vimPlugins.coc-rust-analyzer
      pkgs.vimPlugins.vim-nix
      pkgs.vimPlugins.vim-be-good
      pkgs.vimPlugins.yuck-vim
    ];
  };

  programs.nvchad = {
    enable = true;
  };
}
