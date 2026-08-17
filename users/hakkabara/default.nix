{ ... }:

{

  imports = [
    ./git.nix
    ./nix-dev.nix
    ./vscode.nix
    ./ssh.nix

    ../../modules/home/shell
    ../../modules/home/cli
    ../../modules/home/apps
    ../../modules/home/editor/neovim.nix
    ../../modules/home/terminal/kitty.nix
  ];
  home = {
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
