{ ... }:

{

  imports = [
    ./git.nix
    ./nix-dev.nix
    ./vscode.nix
    ./ssh.nix
    ./firefox.nix

    ../../modules/home/shell
    ../../modules/home/cli
    ../../modules/home/apps
    ../../modules/home/editor/neovim.nix
    ../../modules/home/terminal
  ];
  home = {
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
