{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.dms;

  disableClipboardPersistence = pkgs.writeShellScript "dms-disable-clipboard-persistence" (
    builtins.concatStringsSep "\n" [
      "config_dir=\"$HOME/.config/DankMaterialShell\""
      "config_file=\"$config_dir/clsettings.json\""
      "tmp_file=\"$config_file.tmp\""
      ""
      "mkdir -p \"$config_dir\""
      ""
      "if [ -f \"$config_file\" ] && ${pkgs.jq}/bin/jq empty \"$config_file\" >/dev/null 2>&1; then"
      "  ${pkgs.jq}/bin/jq '.disabled = true' \"$config_file\" > \"$tmp_file\""
      "else"
      "  printf '%s\\n' '{\"disabled\":true}' > \"$tmp_file\""
      "fi"
      ""
      "mv \"$tmp_file\" \"$config_file\""
      "chmod 600 \"$config_file\""
    ]
  );
in
{
  options.hakkabara.desktop.dms.clipboardHistoryPersistence.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Allow DankMaterialShell to persist clipboard history to disk.";
  };

  config = lib.mkIf (!cfg.clipboardHistoryPersistence.enable) {
    home.activation.dmsDisableClipboardHistoryPersistence = lib.hm.dag.entryAfter [
      "writeBoundary"
    ] "${disableClipboardPersistence}";
  };
}
