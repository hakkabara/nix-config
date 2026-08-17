{ pkgs, ... }:

{
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
}
