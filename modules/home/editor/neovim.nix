{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.editor;
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

    programs.zsh.shellAliases = {
      vi = "nvim";
      vim = "nvim";
      vimdiff = "nvim -d";
    };
  };
}
