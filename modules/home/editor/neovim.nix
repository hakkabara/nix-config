{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;

    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withNodeJs = true;
    withPython3 = true;

    extraPackages = with pkgs; [
      # LazyVim / Treesitter prerequisites
      gcc
      tree-sitter

      # Search / fuzzy finding
      ripgrep
      fd
      fzf

      # Required / useful for LazyVim
      git
      curl
      lazygit
    ];
  };
}
