{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.copyq;

  # CopyQ keeps its theme in copyq.conf, which it rewrites itself, so the
  # file cannot be managed. Start the server, wait for it, then load the
  # theme through CopyQ's own loadTheme(); this repeats on every login, so
  # changes made in the GUI last only until the next session.
  copyqStart = pkgs.writeShellScript "copyq-start" (
    ''
      ${pkgs.copyq}/bin/copyq &
    ''
    + lib.optionalString cfg.theme.enable ''
      for _ in $(seq 1 50); do
        if ${pkgs.copyq}/bin/copyq eval 1 >/dev/null 2>&1; then
          exec ${pkgs.copyq}/bin/copyq loadTheme ${./themes/tokyo-night.ini}
        fi
        sleep 0.2
      done
      echo "copyq-start: CopyQ server not reachable, theme not loaded" >&2
    ''
  );
in
{
  options.hakkabara.apps.copyq = {
    enable = lib.mkEnableOption "CopyQ clipboard manager";

    autostart.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start CopyQ automatically with the desktop session.";
    };

    theme.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Load the dark Tokyo Night CopyQ theme at session start.";
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
          "Exec=${copyqStart}"
          "Icon=copyq"
          "Terminal=false"
          "Categories=Utility;"
          "StartupNotify=false"
        ]
        + "\n";
    };
  };
}
