{ ... }:

{

  imports = [
    ./git.nix
    ./nix-dev.nix
    ./vscode.nix
    ./ssh.nix
  ];
  home = {
    username = "hakkabara";
    homeDirectory = "/home/hakkabara";
    stateVersion = "26.05";
  };
}
