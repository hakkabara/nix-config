{ ... }:

{
  imports = [
    # User-specific configuration
    ./git.nix
    ./ssh.nix

    # Shared feature modules
    ../../modules/home/shell
    ../../modules/home/cli
    ../../modules/home/apps
    ../../modules/home/editor
    ../../modules/home/git
    ../../modules/home/nix-dev
    ../../modules/home/terminal
  ];

  home = {
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
