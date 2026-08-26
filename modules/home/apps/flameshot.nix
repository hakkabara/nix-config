{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hakkabara.apps.flameshot = {
    enable = lib.mkEnableOption "Flameshot screenshot tool";

    savePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Pictures/Screenshots";
      description = "Default Flameshot screenshot directory";
    };
  };

  config = lib.mkIf config.hakkabara.apps.flameshot.enable {
    home.packages = [
      pkgs.flameshot
    ];

    xdg.configFile."flameshot/flameshot.ini".text = ''
      [General]
      savePath=${config.hakkabara.apps.flameshot.savePath}
      saveAfterCopy=true
      showDesktopNotification=true
      copyPathAfterSave=false
      filenamePattern=Screenshot_%F_%H-%M-%S
    '';
  };
}
