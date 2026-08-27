{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.python;
in
{
  options.hakkabara.python = {
    python3.enable = lib.mkEnableOption "Python 3 runtime";
  };

  config = lib.mkIf cfg.python3.enable {
    environment.systemPackages = [
      pkgs.python3
    ];
  };
}
