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
          "nvim/plugin/zellij-navigation.lua".text = ''
            -- Nix owns the smart-splits source. Load it directly from the
            -- immutable store instead of relying on Lazy.nvim discovery.
            vim.opt.runtimepath:prepend("${pkgsUnstable.vimPlugins.smart-splits-nvim}")

            -- Explicitly select Zellij instead of relying on auto-detection.
            vim.g.smart_splits_multiplexer_integration = "zellij"

            local splits = require("smart-splits")

            splits.setup({
              multiplexer_integration = "zellij",
              zellij_move_focus_or_tab = false,
            })

            local function set_navigation_keymaps()
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
            end

            -- Set them immediately and once again after LazyVim has installed
            -- its default keymaps so LazyVim cannot overwrite them.
            set_navigation_keymaps()

            vim.api.nvim_create_autocmd("User", {
              pattern = "VeryLazy",
              once = true,
              callback = set_navigation_keymaps,
            })
          '';
        };

    programs.zsh.shellAliases = {
      vi = "nvim";
      vim = "nvim";
      vimdiff = "nvim -d";
    };
  };
}
