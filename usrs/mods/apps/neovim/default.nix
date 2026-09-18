{
  config,
  pkgs,
  ...
}: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Theme picker (no nixvim module exists for themery)
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

    # Binaries exposed on neovim's PATH (ripgrep for in-editor search,
    # opencode for opencode.nvim's `term://opencode` server launch)
    extraPackages = with pkgs; [
      ripgrep
      opencode
    ];

    # Plugins (Declarative equivalents)
    plugins = {
      render-markdown.enable = true;

      # UI Components
      bufferline = {
        enable = true;
        settings.options = {
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

      # EWW filetype
      yuck.enable = true;

      # AI assistant (keymaps below; bare `opencode` binary via extraPackages)
      opencode.enable = true;

      # Treesitter (grammars installed purely via Nix)
      treesitter = {
        enable = true;

        # Overrides nixvim's all-grammars default, so keep the parsers Neovim's
        # own features and render-markdown rely on: query/regex/vim/vimdoc and
        # markdown_inline (render-markdown).
        grammarPackages = with config.programs.nixvim.plugins.treesitter.package.builtGrammars; [
          bash
          c
          cpp
          css
          html
          javascript
          typescript
          tsx
          json
          lua
          nix
          python
          rust
          go
          svelte
          markdown
          markdown_inline
          query
          regex
          vim
          vimdoc
          wgsl
        ];

        highlight = {
          enable = true;
        };
      };

      # LSP Configuration
      lsp = {
        enable = true;
        keymaps = {
          silent = true;
          lspBuf = {
            gd = "definition";
            gD = "declaration";
            gr = "references";
            gi = "implementation";
            K = "hover";
            "<leader>ca" = "code_action";
            "<leader>rn" = "rename";
          };
          diagnostic = {
            "[d" = "goto_prev";
            "]d" = "goto_next";
            "<leader>j" = "goto_next";
            "<leader>k" = "goto_prev";
            "<leader>d" = "open_float";
            "<leader>q" = "setloclist";
          };
        };
        servers = {
          nil_ls.enable = true; # Nix
          rust_analyzer = {
            # Rust (Replacing coc-rust-analyzer). No rustc/cargo in the system
            # config, so let nixvim provide them or the LSP is incomplete.
            enable = true;
            installCargo = true;
            installRustc = true;
          };
          pyright.enable = true; # Python
          ts_ls.enable = true; # JS/TS
          lua_ls.enable = true; # Lua
          svelte.enable = true;
          wgsl_analyzer.enable = true;
        };
      };

      # Completion
      cmp = {
        enable = true;

        settings = {
          sources = [
            {name = "nvim_lsp";}
          ];

          mapping = {
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = "cmp.mapping.select_next_item()";
            "<S-Tab>" = "cmp.mapping.select_prev_item()";
          };
        };
      };
    };

    # Theme plugins installed raw on purpose: nixvim's `colorschemes.*` modules
    # each set `colorscheme` via mkDefault, so enabling several would conflict
    # with each other and with Themery, which switches colorschemes at runtime.
    # themery-nvim has no nixvim module.
    extraPlugins = with pkgs.vimPlugins; [
      # unfree; nixvim's `plugins.vim-be-good` module trips nixpkgs'
      # allowUnfree check during eval, so install the plugin raw instead.
      vim-be-good

      themery-nvim
      catppuccin-nvim
      gruvbox-nvim
      kanagawa-nvim
    ];

    # Keymaps (The clean Nix way)
    keymaps = [
      # Buffers (S-h/S-l are just H/L, so this intentionally overrides those
      # motions; Tab/S-Tab stay free for cmp, which maps them in insert only)
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>BufferLineCycleNext<CR>";
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>BufferLineCyclePrev<CR>";
      }

      # Toggles
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
      }
      {
        mode = "n";
        key = "<leader>te";
        action = "<cmd>Themery<CR>";
      }
      {
        mode = "n";
        key = "<C-s>";
        action = "<cmd>w<CR>";
      }

      # Navigation (Normal)
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
      }

      # Navigation (Terminal)
      {
        mode = "t";
        key = "<C-h>";
        action = "<C-\\><C-n><C-w>h";
      }
      {
        mode = "t";
        key = "<C-j>";
        action = "<C-\\><C-n><C-w>j";
      }
      {
        mode = "t";
        key = "<C-k>";
        action = "<C-\\><C-n><C-w>k";
      }
      {
        mode = "t";
        key = "<C-l>";
        action = "<C-\\><C-n><C-w>l";
      }
      {
        mode = "t";
        key = "<Esc>";
        action = "<C-\\><C-n>";
      }

      # ToggleTerm
      {
        mode = "t";
        key = "<leader>tt";
        action = "<C-\\><C-n><cmd>ToggleTerm<CR>";
      } # toggle within terminal
      {
        mode = "n";
        key = "<leader>tt";
        action = "<cmd>ToggleTerm<CR>";
      }
      {
        mode = "n";
        key = "<leader>t1";
        action = "<cmd>ToggleTerm 1<CR>";
      }
      {
        mode = "n";
        key = "<leader>t2";
        action = "<cmd>ToggleTerm 2 direction=horizontal<CR>";
      }

      # Resizing
      {
        mode = "n";
        key = "<A-Left>";
        action = "<cmd>vertical resize -2<CR>";
      }
      {
        mode = "n";
        key = "<A-Right>";
        action = "<cmd>vertical resize +2<CR>";
      }

      # OpenCode (opencode.nvim). Upstream's defaults, but note <C-,> and
      # <S-C-u>/<S-C-d> need a terminal that sends them (kitty's keyboard
      # protocol does); in others they collapse to <C-u>/<C-d> or never fire.
      {
        mode = ["n" "x"];
        key = "<C-,>";
        action.__raw = ''function() require("opencode").ask("@this: ") end'';
        options.desc = "Ask OpenCode";
      }
      {
        mode = ["n" "x"];
        key = "<leader>os";
        action.__raw = ''function() require("opencode").select() end'';
        options.desc = "Select OpenCode";
      }
      {
        mode = ["n" "x"];
        key = "go";
        action.__raw = ''require("opencode").operator("@this ")'';
        options = {
          expr = true;
          desc = "Send to OpenCode";
        };
      }
      {
        mode = "n";
        key = "<S-C-u>";
        action.__raw = ''function() require("opencode").command("session.half.page.up") end'';
        options.desc = "Scroll OpenCode up";
      }
      {
        mode = "n";
        key = "<S-C-d>";
        action.__raw = ''function() require("opencode").command("session.half.page.down") end'';
        options.desc = "Scroll OpenCode down";
      }
    ];
  };
}
