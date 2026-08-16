{ ... }:

{

  imports = [
    ./git.nix
    ./nix-dev.nix
    ./vscode.nix
  ];
  home = {
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
