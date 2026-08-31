{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.dms;

  dmsTokyoNightTheme = pkgs.writeText "dms-tokyo-night.json" (
    builtins.toJSON {
      dark = {
        name = "Tokyo Night";

        primary = "#7aa2f7";
        primaryText = "#1a1b26";
        primaryContainer = "#3d59a1";

        secondary = "#bb9af7";

        surface = "#1a1b26";
        surfaceText = "#c0caf5";

        surfaceVariant = "#24283b";
        surfaceVariantText = "#a9b1d6";

        surfaceTint = "#7aa2f7";

        background = "#16161e";
        backgroundText = "#c0caf5";

        outline = "#3b4261";

        surfaceContainer = "#1f2335";
        surfaceContainerHigh = "#24283b";
        surfaceContainerHighest = "#292e42";

        error = "#f7768e";
        warning = "#e0af68";
        info = "#7dcfff";

        matugen_type = "scheme-tonal-spot";
      };
    }
  );

  applyTokyoNightTheme = pkgs.writeShellScript "dms-apply-tokyo-night-theme" ''
    config_dir="$HOME/.config/DankMaterialShell"
    config_file="$config_dir/settings.json"
    tmp_file="$config_file.tmp"

    mkdir -p "$config_dir"

    if [ -f "$config_file" ] && ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq         --arg theme "$HOME/.config/DankMaterialShell/themes/tokyo-night.json"         '.currentThemeName = "custom"
         | .customThemeFile = $theme
         | .cornerRadius = 12
         | .animationSpeed = 1
         | .dankBarTransparency = 0.35
         | .dankBarWidgetTransparency = 0.90
         | .innerPadding = 6
         | if (.barConfigs | type) == "array"
           then .barConfigs |= map(
             if type == "object"
             then .innerPadding = 6
             else .
             end
           )
           else .
           end'          "$config_file" > "$tmp_file"
    else
      ${pkgs.jq}/bin/jq -n         --arg theme "$HOME/.config/DankMaterialShell/themes/tokyo-night.json"         '{
          currentThemeName: "custom",
          customThemeFile: $theme,
          cornerRadius: 12,
          animationSpeed: 1,
          dankBarTransparency: 0.35,
          dankBarWidgetTransparency: 0.90,
          innerPadding: 6
        }' > "$tmp_file"
    fi

    mv "$tmp_file" "$config_file"
    chmod 600 "$config_file"
  '';

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

  config = {
    xdg.configFile."DankMaterialShell/themes/tokyo-night.json".source = dmsTokyoNightTheme;

    home.activation.dmsApplyTokyoNightTheme = lib.hm.dag.entryAfter [
      "writeBoundary"
    ] "${applyTokyoNightTheme}";

    home.activation.dmsDisableClipboardHistoryPersistence =
      lib.mkIf (!cfg.clipboardHistoryPersistence.enable)
        (
          lib.hm.dag.entryAfter [
            "dmsApplyTokyoNightTheme"
          ] "${disableClipboardPersistence}"
        );
  };
}
