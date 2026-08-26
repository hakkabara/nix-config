{ config, lib, ... }:

let
  cfg = config.hakkabara.desktop.autologin;
in
{
  options.hakkabara.desktop.autologin = {
    enable = lib.mkEnableOption "automatic graphical login";

    user = lib.mkOption {
      type = lib.types.str;
      default = "hakkabara";
      description = "User account used for graphical automatic login.";
    };

    session = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Display manager session used for automatic login.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.displayManager.autoLogin = {
        enable = true;
        inherit (cfg) user;
      };
    })

    (lib.mkIf (cfg.enable && cfg.session != null) {
      services.displayManager.defaultSession = cfg.session;
    })
  ];
}
