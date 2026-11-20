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

  # smart-splits v3 ships no multiplexer backends in core. The Zellij backend
  # is a separate plugin that nixpkgs does not package yet.
  smartSplitsBackendZellij = pkgsUnstable.vimUtils.buildVimPlugin {
    pname = "smart-splits-backend-zellij-lua";
    version = "1.0.0";

    src = pkgsUnstable.fetchFromGitHub {
      owner = "smart-splits-nvim";
      repo = "backend-zellij-lua";
      tag = "v1.0.0";
      hash = "sha256-QAKX3jHYd2xHjhs8uf44OB04Q+Gl+wXVZOqS09IcRSk=";
    };

    dependencies = [ pkgsUnstable.vimPlugins.smart-splits-nvim ];
  };
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
            vim.opt.runtimepath:prepend("${smartSplitsBackendZellij}")

            -- Stay inside the current tab when navigating past an edge pane.
            require("smart-splits-backend-zellij-lua").setup({
              move_cursor = { pane_or_tab = false },
            })

            local splits = require("smart-splits")

            -- v3 has no auto-detection; the backend is named explicitly.
            -- Neovim also runs outside Zellij (plain Kitty, SSH), where plain
            -- window movement is the intended fallback, not a problem.
            splits.setup({
              mux = {
                backend = "smart-splits-backend-zellij-lua",
                warn_if_unusable = false,
              },
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
