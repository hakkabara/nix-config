{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.desktop.plasma;
  scriptId = "hakkabara-window-layout";
in
{
  options.hakkabara.desktop.plasma.windowLayout.enable =
    lib.mkEnableOption "fixed application workspace layout";

  config = lib.mkIf (cfg.enable && cfg.windowLayout.enable) {
    xdg.dataFile."kwin/scripts/${scriptId}" = {
      source = ./package;
      recursive = true;
    };

    programs.plasma.configFile.kwinrc.Plugins."${scriptId}Enabled" = true;
  };
}
