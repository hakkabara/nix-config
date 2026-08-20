{ lib, ... }:

{
  imports = [
    ./neovim.nix
    ./vscode.nix
  ];

  options.hakkabara.editor = {
    enable = lib.mkEnableOption "shared editor environment";

    neovim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Neovim as part of the editor environment.";
    };

    vscode.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Visual Studio Code as part of the editor environment.";
    };
  };
}
