{ lib, ... }:

{
  imports = [
    ./kitty.nix
    ./konsole.nix
    ./tmux.nix
    ./zellij
    ./lnav
  ];

  options.hakkabara.terminal = {
    enable = lib.mkEnableOption "shared terminal environment";

    kitty.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Kitty as part of the terminal environment.";
    };

    konsole.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable KDE Konsole as part of the terminal environment.";
    };

    tmux.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable tmux as part of the terminal environment.";
    };

    zellij.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zellij as part of the terminal environment.";
    };

    lnav.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable lnav and its managed formats.";
    };
  };
}
