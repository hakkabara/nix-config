{ lib, ... }:

{
  imports = [
    ./cli.nix
  ];

  # CLI-first administration profile.
  #
  # The DeployVM deliberately starts without a desktop environment. If a GUI
  # proves genuinely useful later, it will become a separate optional layer
  # rather than part of the trusted minimal baseline.
  hakkabara = {
    cli.sshelf.enable = lib.mkDefault true;

    terminal = {
      enable = lib.mkDefault true;

      kitty.enable = lib.mkDefault false;
      konsole.enable = lib.mkDefault false;

      tmux.enable = lib.mkDefault true;
      zellij.enable = lib.mkDefault true;
      lnav.enable = lib.mkDefault true;
    };

    editor = {
      enable = lib.mkDefault true;

      neovim.enable = lib.mkDefault true;
      vscode.enable = lib.mkDefault false;
    };

    nixDev.enable = lib.mkDefault true;
  };
}
