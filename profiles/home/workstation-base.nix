{ lib, ... }:

{
  # Shared baseline for interactive workstation-like systems.
  #
  # mkDefault intentionally gives individual hosts the ability to override
  # these choices without requiring mkForce.
  hakkabara = {
    terminal.enable = lib.mkDefault true;
    cli.enable = lib.mkDefault true;
    shell.enable = lib.mkDefault true;

    editor.enable = lib.mkDefault true;

    git.enable = lib.mkDefault true;
    nixDev.enable = lib.mkDefault true;
  };
}
