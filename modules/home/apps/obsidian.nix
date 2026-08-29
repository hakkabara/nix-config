{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hakkabara.apps.obsidian.enable = lib.mkEnableOption "Obsidian knowledge base application";

  config = lib.mkIf config.hakkabara.apps.obsidian.enable {
    home.packages = [
      pkgs.obsidian
    ];
  };
}
