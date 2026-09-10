{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.dms;
in
{
  options.hakkabara.desktop.dms = {
    enable = lib.mkEnableOption "DankMaterialShell";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dms-shell;
      description = "DMS package to use.";
    };

    quickshellPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.quickshell;
      description = "Quickshell package used by DMS.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.dms-shell = {
      enable = true;

      inherit (cfg) package;
      quickshell.package = cfg.quickshellPackage;

      systemd.enable = true;
    };
  };
}
