{ pkgs, ...}:
{
  programs.neovim = {
    enable = true;
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
}
