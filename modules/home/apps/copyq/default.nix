{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.copyq;
in
{
  options.hakkabara.apps.copyq = {
    enable = lib.mkEnableOption "CopyQ clipboard manager";

    autostart.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start CopyQ automatically with the desktop session.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.copyq
    ];

    xdg.configFile."autostart/copyq.desktop" = lib.mkIf cfg.autostart.enable {
      text =
        builtins.concatStringsSep "\n" [
          "[Desktop Entry]"
          "Type=Application"
          "Name=CopyQ"
          "Comment=Clipboard Manager"
          "Exec=${pkgs.copyq}/bin/copyq"
          "Icon=copyq"
          "Terminal=false"
          "Categories=Utility;"
          "StartupNotify=false"
        ]
        + "\n";
    };
  };
}
