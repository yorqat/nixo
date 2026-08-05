{ pkgs, ... }: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Actually start Themery
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

      require('claude-code').setup({
          -- Terminal window settings
  window = {
    split_ratio = 0.3,      -- Percentage of screen for the terminal window (height for horizontal, width for vertical splits)
    position = "botright",  -- Position of the window: "botright", "topleft", "vertical", "float", etc.
    enter_insert = true,    -- Whether to enter insert mode when opening Claude Code
    hide_numbers = true,    -- Hide line numbers in the terminal window
    hide_signcolumn = true, -- Hide the sign column in the terminal window
    
    -- Floating window configuration (only applies when position = "float")
    float = {
      width = "80%",        -- Width: number of columns or percentage string
      height = "80%",       -- Height: number of rows or percentage string
      row = "center",       -- Row position: number, "center", or percentage string
      col = "center",       -- Column position: number, "center", or percentage string
      relative = "editor",  -- Relative to: "editor" or "cursor"
      border = "rounded",   -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
    },
  },
  -- File refresh settings
  refresh = {
    enable = true,           -- Enable file change detection
    updatetime = 100,        -- updatetime when Claude Code is active (milliseconds)
    timer_interval = 1000,   -- How often to check for file changes (milliseconds)
    show_notifications = true, -- Show notification when files are reloaded
  },
  -- Git project settings
  git = {
    use_git_root = true,     -- Set CWD to git root when opening Claude Code (if in git project)
  },
  -- Shell-specific settings
  shell = {
    separator = '&&',        -- Command separator used in shell commands
    pushd_cmd = 'pushd',     -- Command to push directory onto stack (e.g., 'pushd' for bash/zsh, 'enter' for nushell)
    popd_cmd = 'popd',       -- Command to pop directory from stack (e.g., 'popd' for bash/zsh, 'exit' for nushell)
  },
  -- Command settings
  command = "claude",        -- Command used to launch Claude Code
  -- Command variants
  command_variants = {
    -- Conversation management
    continue = "--continue", -- Resume the most recent conversation
    resume = "--resume",     -- Display an interactive conversation picker

    -- Output options
    verbose = "--verbose",   -- Enable verbose logging with full turn-by-turn output
  },
  -- Keymaps
  keymaps = {
    toggle = {
      normal = "<C-,>",       -- Normal mode keymap for toggling Claude Code, false to disable
      terminal = "<C-,>",     -- Terminal mode keymap for toggling Claude Code, false to disable
      variants = {
        continue = "<leader>cC", -- Normal mode keymap for Claude Code with continue flag
        verbose = "<leader>cV",  -- Normal mode keymap for Claude Code with verbose flag
      },
    },
    window_navigation = true, -- Enable window navigation keymaps (<C-h/j/k/l>)
    scrolling = true,         -- Enable scrolling keymaps (<C-f/b>) for page up/down
  }
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
      render-markdown.enable = true;

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

        highlight = {
          enable = true;
        };

        settings.ensure_installed = [
          "bash" "c" "cpp" "css" "html" "javascript" "typescript" "tsx" 
          "json" "lua" "nix" "python" "rust" "go" "svelte" "markdown" "wgsl"
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
          wgsl_analyzer.enable = true;
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

      claude-code-nvim
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
