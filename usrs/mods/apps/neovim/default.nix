{
  config,
  pkgs,
  ...
}: {
  stylix.targets.nixvim.enable = true;
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # cmp's mappings are deliberately absent from `plugins.cmp.settings` and set
    # per buffer here: nixvim emits a single global cmp.setup(), and a `mapping`
    # entry in it is an insert-mode map in *every* buffer, so <Tab>/<CR> would be
    # swallowed in filetypes that have no nvim_lsp source (markdown, txt, help,
    # yuck/eww files). <C-n>/<C-p> additionally keep <Tab> free for whatever the
    # filetype wants it for.
    extraConfigLua = ''
      local cmp_buffer_group =
        vim.api.nvim_create_augroup("cmp_buffer_mappings", { clear = true })

      vim.api.nvim_create_autocmd("InsertEnter", {
        group = cmp_buffer_group,
        callback = function()
          local cmp = require("cmp")
          cmp.setup.buffer({
            mapping = cmp.mapping.preset.insert(),
          })
        end,
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

    # Space for Leader key. maplocalleader is deliberately left at its default
    # `\`: giving local and global leader the same key collapses two namespaces
    # (a plugin's buffer-local <leader> map then silently shadows these) and a
    # later mapleader change would only half-apply, because nixvim sets the lsp
    # keymaps with `buffer = args.buf`, where <leader> expands to the *local*
    # leader.
    globals = {
      mapleader = " ";
    };

    # Binaries exposed on neovim's PATH (ripgrep for in-editor search,
    # opencode for opencode.nvim's `term://opencode` server launch)
    extraPackages = with pkgs; [
      ripgrep
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

      # Leader-key discovery: every mapping below carries a `desc`, and this is
      # what actually surfaces them after <leader>.
      which-key.enable = true;

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

        # Only non-leader, non-prefix keys here. Two reasons:
        #   * nixvim installs these on LspAttach with `buffer = args.buf`, so a
        #     <leader> prefix would resolve against maplocalleader rather than
        #     the mapleader the other keymaps in this file use.
        #   * nvim >= 0.11 binds `gra` (code action), `gri` (implementation),
        #     `grn` (rename), `grr` (references), `grt` and `grx` globally at
        #     startup (`:h lsp-defaults`). A `gr` mapping on top of those turns
        #     all six into ambiguous prefixes that wait out `timeoutlen`.
        # Code action, rename, implementation and references are therefore the
        # built-in gr* keys; definition/declaration/hover are below.
        keymaps = {
          silent = true;
          lspBuf = {
            gd = "definition";
            gD = "declaration";
            K = "hover";
          };
          diagnostic = {
            "[d" = "goto_prev";
            "]d" = "goto_next";
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
    ];

    # Keymaps (The clean Nix way)
    keymaps = [
      # Buffers (S-h/S-l are just H/L, so this intentionally overrides those
      # motions)
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>BufferLineCycleNext<CR>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>BufferLineCyclePrev<CR>";
        options.desc = "Previous buffer";
      }

      # Toggles
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<CR>";
        options.desc = "Explorer";
      }
      {
        # Normal mode only: i_CTRL-S is signature help since nvim 0.11.
        mode = "n";
        key = "<C-s>";
        action = "<cmd>w<CR>";
        options.desc = "Save";
      }
      {
        # Was LSP-scoped; nothing about the location list is LSP-specific.
        mode = "n";
        key = "<leader>q";
        action = "<cmd>setloclist<CR>";
        options.desc = "Location list";
      }

      # Navigation (Normal)
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        options.desc = "Window left";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        options.desc = "Window down";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        options.desc = "Window up";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        options.desc = "Window right";
      }

      # Navigation (Terminal)
      {
        mode = "t";
        key = "<C-h>";
        action = "<C-\\><C-n><C-w>h";
        options.desc = "Window left";
      }
      {
        mode = "t";
        key = "<C-j>";
        action = "<C-\\><C-n><C-w>j";
        options.desc = "Window down";
      }
      {
        mode = "t";
        key = "<C-k>";
        action = "<C-\\><C-n><C-w>k";
        options.desc = "Window up";
      }
      {
        mode = "t";
        key = "<C-l>";
        action = "<C-\\><C-n><C-w>l";
        options.desc = "Window right";
      }
      {
        mode = "t";
        key = "<Esc>";
        action = "<C-\\><C-n>";
        options.desc = "Terminal normal mode";
      }

      # ToggleTerm. Two terminals: 1 is the default vertical split <leader>tt
      # acts on, 2 is the horizontal one (toggleterm creates it on first use).
      # No <leader> mapping in terminal mode: there it is just a prefix that
      # eats shell input and makes every space wait out `timeoutlen`
      # (`git tag tt` would toggle the terminal instead of typing).
      {
        mode = "n";
        key = "<leader>tt";
        action = "<cmd>ToggleTerm<CR>";
        options.desc = "Terminal";
      }
      {
        mode = "n";
        key = "<leader>t2";
        action = "<cmd>ToggleTerm 2 direction=horizontal<CR>";
        options.desc = "Terminal (horizontal)";
      }

      # Resizing. <A-hjkl> mirrors the <C-hjkl> cluster above and survives
      # terminals that swallow Alt+arrow keys; the built-in <C-w>_ / <C-w>|
      # still cover max-height/max-width.
      {
        mode = "n";
        key = "<A-h>";
        action = "<cmd>vertical resize -2<CR>";
        options.desc = "Narrow window";
      }
      {
        mode = "n";
        key = "<A-l>";
        action = "<cmd>vertical resize +2<CR>";
        options.desc = "Widen window";
      }
      {
        mode = "n";
        key = "<A-j>";
        action = "<cmd>resize -2<CR>";
        options.desc = "Shorten window";
      }
      {
        mode = "n";
        key = "<A-k>";
        action = "<cmd>resize +2<CR>";
        options.desc = "Heighten window";
      }

      # OpenCode (opencode.nvim). Upstream's keys, except the scroll pair:
      # <S-C-u>/<S-C-d> need a terminal that sends them (kitty's keyboard
      # protocol does) and collapse to <C-u>/<C-d> — page scroll — elsewhere.
      # <C-e>/<C-y> are unbound in normal mode and fire in any terminal.
      {
        mode = ["n" "x"];
        key = "<leader>cc";
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
        key = "<C-e>";
        action.__raw = ''function() require("opencode").command("session.half.page.up") end'';
        options.desc = "Scroll OpenCode up";
      }
      {
        mode = "n";
        key = "<C-y>";
        action.__raw = ''function() require("opencode").command("session.half.page.down") end'';
        options.desc = "Scroll OpenCode down";
      }
    ];
  };
}
