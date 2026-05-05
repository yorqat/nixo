{pkgs, ...}: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # 2. Actually start Themery
    extraConfigLua = ''
      require("themery").setup({
        themes = {
          "catppuccin-latte",
          "catppuccin-frappe",
          "catppuccin-macchiato",
          "catppuccin-mocha",
          "gruvbox",
          "kanagawa-wave",
          "kanagawa-dragon",
          "kanagawa-lotus",
        },
        livePreview = true,
      })
    '';

    opts = {
      number = true;
      relativenumber = true;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      showtabline = 2;
    };

    # Space for Leader key
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # System Packages (replaces extraPackages)
    extraPackages = with pkgs; [
      ripgrep
    ];

    # Plugins (Declarative equivalents)
    plugins = {
      keymaps = {
        silent = true;
        # Expected LSP Bindings
        lspBuf = {
          gd = "definition";
          gD = "declaration";
          gr = "references";
          gi = "implementation";
          K = "hover";

          "<leader>ca" = "code_action";
          "<leader>rn" = "rename";
          "[d" = "goto_prev";
          "]d" = "goto_next";
          "<leader>e" = "open_float";
          "<leader>q" = "setloclist";
        };

        diagnostic = {
          "<leader>j" = "goto_next";
          "<leader>k" = "goto_prev";
        };
      };

      # Theming
      themery = {
        enable = true;
        settings = {
          themes = [
            "catppuccin-latte" "catppuccin-frappe" "catppuccin-macchiato" "catppuccin-mocha"
            "gruvbox" "kanagawa"
          ];
          livePreview = true;
        };
      };

      # UI Components
      bufferline = {
        enable = true;
        settings.options = {
          mode = "buffers";
          separator_style = "slant";
          diagnostics = "nvim_lsp";
        };
      };

      toggleterm = {
        enable = true;
        settings = {
          start_in_insert = true;
          persist_mode = false;
          close_on_exit = true;
          shading_factor = 0;
        };
      };

      neo-tree.enable = true;
      web-devicons.enable = true;

      # Treesitter (Nixvim handles the grammar installations)
      treesitter = {
        enable = true;
        nixGrammars = true;
        settings.ensure_installed = [
          "bash" "c" "cpp" "css" "html" "javascript" "typescript" "tsx" 
          "json" "lua" "nix" "python" "rust" "go" "svelte" "markdown"
        ];
      };

      # LSP Configuration
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true;      # Nix
          rust_analyzer = {          # Rust (Replacing coc-rust-analyzer)
            enable = true;
            installCargo = false;
            installRustc = false;
          };
          pyright.enable = true;     # Python
          ts_ls.enable = true;       # JS/TS
          lua_ls.enable = true;      # Lua
          svelte.enable = true;
        };
      };

      # Completion
      cmp = {
        enable = true;

        settings = {
          sources = [
            { name = "nvim_lsp"; }
          ];

          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = "cmp.mapping.select_next_item()";
            "<S-Tab>" = "cmp.mapping.select_prev_item()";
          };
        };
      };
    };

    # Extra Plugins (for those without a dedicated Nixvim module yet)
    extraPlugins = with pkgs.vimPlugins; [
      vim-be-good
      yuck-vim

      themery-nvim
      catppuccin-nvim
      gruvbox-nvim
      tokyonight-nvim
      kanagawa-nvim
    ];

    # Keymaps (The clean Nix way)
    keymaps = [
      # Buffers
      { mode = "n"; key = "<Tab>"; action = ":BufferLineCycleNext<CR>"; }
      { mode = "n"; key = "<S-Tab>"; action = ":BufferLineCyclePrev<CR>"; }
      
      # Toggles
      { mode = "n"; key = "<leader>e"; action = ":Neotree toggle<CR>"; }
      { mode = "n"; key = "<leader>te"; action = ":Themery<CR>"; }
      { mode = "n"; key = "<C-s>"; action = ":w<CR>"; }

      # Navigation (Normal)
      { mode = "n"; key = "<C-h>"; action = "<C-w>h"; }
      { mode = "n"; key = "<C-j>"; action = "<C-w>j"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w>k"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w>l"; }

      # Navigation (Terminal)
      { mode = "t"; key = "<C-h>"; action = "<C-\\><C-n><C-w>h"; }
      { mode = "t"; key = "<C-j>"; action = "<C-\\><C-n><C-w>j"; }
      { mode = "t"; key = "<C-k>"; action = "<C-\\><C-n><C-w>k"; }
      { mode = "t"; key = "<C-l>"; action = "<C-\\><C-n><C-w>l"; }
      { mode = "t"; key = "<Esc>"; action = "<C-\\><C-n>"; }

      # ToggleTerm
      { mode = "t"; key = "<leader>tt"; action = "<C-\\><C-n><cmd>ToggleTerm<CR>"; } # toggle within terminal
      { mode = "n"; key = "<leader>tt"; action = "<cmd>ToggleTerm<CR>"; }
      { mode = "n"; key = "<leader>t1"; action = "<cmd>ToggleTerm 1<CR>"; }
      { mode = "n"; key = "<leader>t2"; action = "<cmd>ToggleTerm 2 direction=horizontal<CR>"; }


      # Resizing
      { mode = "n"; key = "<A-Left>";  action = "<cmd>vertical resize -2<CR>"; }
      { mode = "n"; key = "<A-Right>"; action = "<cmd>vertical resize +2<CR>"; }
    ];
  };
}
