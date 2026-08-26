{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.editor;
  terminalCfg = config.hakkabara.terminal;
in
{
  config = lib.mkIf (cfg.enable && cfg.neovim.enable) {
    home = {
      packages = with pkgs; [
        neovim

        # LazyVim / Treesitter prerequisites
        gcc
        tree-sitter

        # Search / fuzzy finding
        ripgrep
        fd
        fzf

        # Git / network
        git
        curl
        lazygit
      ];

      sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    };

    # Keep the existing LazyVim installation user-facing, but manage this
    # integration file declaratively. Lazy.nvim loads smart-splits from the
    # immutable Nix store instead of cloning it from GitHub.
    # smart-splits is only deployed when the matching Zellij
    # navigator plugin is enabled. Disabling the plugin therefore
    # removes both sides of the integration.
    xdg.configFile =
      lib.mkIf
        (terminalCfg.enable && terminalCfg.zellij.enable && terminalCfg.zellij.plugins.navigator.enable)
        {
          "nvim/lua/plugins/zellij-navigation.lua".text = ''
            return {
              {
                -- Lazy.nvim only loads the local source. Nix owns downloading,
                -- versioning and pinning of smart-splits.
                name = "smart-splits.nvim",
                dir = "${pkgsUnstable.vimPlugins.smart-splits-nvim}",

                -- Multiplexer integration should be ready immediately.
                lazy = false,

                opts = {
                  -- Pane navigation and tab navigation are intentionally separate.
                  zellij_move_focus_or_tab = false,
                },

                config = function(_, opts)
                  local splits = require("smart-splits")

                  splits.setup(opts)

                  -- Navigation: same Vim directions inside Neovim and across Zellij.
                  vim.keymap.set("n", "<C-h>", splits.move_cursor_left, {
                    desc = "Move left across Neovim/Zellij",
                  })
                  vim.keymap.set("n", "<C-j>", splits.move_cursor_down, {
                    desc = "Move down across Neovim/Zellij",
                  })
                  vim.keymap.set("n", "<C-k>", splits.move_cursor_up, {
                    desc = "Move up across Neovim/Zellij",
                  })
                  vim.keymap.set("n", "<C-l>", splits.move_cursor_right, {
                    desc = "Move right across Neovim/Zellij",
                  })

                  -- Resize follows the same directional muscle memory.
                  vim.keymap.set("n", "<A-h>", splits.resize_left, {
                    desc = "Resize left",
                  })
                  vim.keymap.set("n", "<A-j>", splits.resize_down, {
                    desc = "Resize down",
                  })
                  vim.keymap.set("n", "<A-k>", splits.resize_up, {
                    desc = "Resize up",
                  })
                  vim.keymap.set("n", "<A-l>", splits.resize_right, {
                    desc = "Resize right",
                  })
                end,
              },
            }
          '';
        };
    programs.zsh.shellAliases = {
      vi = "nvim";
      vim = "nvim";
      vimdiff = "nvim -d";
    };
  };
}
