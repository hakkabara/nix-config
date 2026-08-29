{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.apps.keepassxc;
in
{
  options.hakkabara.apps.keepassxc.enable = lib.mkEnableOption "KeePassXC password manager";

  config = lib.mkIf cfg.enable {
    programs.keepassxc.enable = true;
  };
}
