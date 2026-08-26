{ config, lib, ... }:

with lib;

let
  cfg = config.hakkabara.desktop.autologin;
in
{
  options.hakkabara.desktop.autologin = {
    enable = mkEnableOption "automatic graphical login";

    user = mkOption {
      type = types.str;
      default = "hakkabara";
      description = "User for automatic login";
    };
  };

  config = mkIf cfg.enable {
    services.displayManager.autoLogin = {
      enable = true;
      inherit (cfg) user;
    };
  };
}
