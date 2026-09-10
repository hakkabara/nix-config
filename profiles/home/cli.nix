{ lib, ... }:

{
  imports = [
    ./base.nix
  ];

  # Shared command-line tool environment.
  hakkabara.cli.enable = lib.mkDefault true;
}
