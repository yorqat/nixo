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
      pkgs.vimPlugins.CopilotChat-nvim
    ];
  };

  programs.nvchad = {
    enable = true;
    extraConfig = ''local lspconfig = require('lspconfig')

      lspconfig.svelte.setup {
        -- Optional: extra capabilities if you're using nvim-cmp
        capabilities = require('cmp_nvim_lsp').default_capabilities(),
        on_attach = function(client, bufnr)
        -- Optional keybinds or settings per buffer
        local bufmap = function(mode, lhs, rhs)
          vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, { noremap = true, silent = true })
        end

      bufmap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
      bufmap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>')
  end
}
    '';
  };
}
