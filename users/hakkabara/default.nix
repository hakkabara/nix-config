{ ... }:

{
  imports = [
    # User-specific configuration
    ./git.nix
    ./ssh.nix
    ./browser-extensions.nix

    # Shared feature modules
    ../../modules/home/shell
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
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
