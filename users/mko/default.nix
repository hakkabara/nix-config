{ ... }:

{
  imports = [
    ./git.nix

    ../../modules/home/shell
    ../../modules/home/ssh
    ../../modules/home/cli
    ../../modules/home/apps
    ../../modules/home/ai
    ../../modules/home/editor
    ../../modules/home/git
    ../../modules/home/nix-dev
    ../../modules/home/terminal
    ../../modules/home/theme
  ];

  home = {
    username = "mko";
    homeDirectory = "/home/mko";
    stateVersion = "26.05";
  };
}
