{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.desktop.dms;

  controlCenterFilter = lib.optionalString cfg.controlCenter.enable ''
    | .controlCenterShowNetworkIcon = ${lib.boolToString cfg.controlCenter.icons.network}
    | .controlCenterShowBluetoothIcon = ${lib.boolToString cfg.controlCenter.icons.bluetooth}
    | .controlCenterShowAudioIcon = ${lib.boolToString cfg.controlCenter.icons.audio}
    | .controlCenterShowVpnIcon = ${lib.boolToString cfg.controlCenter.icons.vpn}
    | .controlCenterShowBrightnessIcon = ${lib.boolToString cfg.controlCenter.icons.brightness}
    | .controlCenterShowMicIcon = ${lib.boolToString cfg.controlCenter.icons.mic}
    | .controlCenterShowBatteryIcon = ${lib.boolToString cfg.controlCenter.icons.battery}
    | .controlCenterShowScreenSharingIcon = ${lib.boolToString cfg.controlCenter.icons.screenSharing}

    | .controlCenterWidgets = (
        (
          if (.controlCenterWidgets | type) == "array" then
            .controlCenterWidgets
          else
            [
              { id: "volumeSlider", enabled: true, width: 50 },
              { id: "brightnessSlider", enabled: true, width: 50 },
              { id: "wifi", enabled: true, width: 50 },
              { id: "bluetooth", enabled: true, width: 50 },
              { id: "audioOutput", enabled: true, width: 50 },
              { id: "audioInput", enabled: true, width: 50 },
              { id: "nightMode", enabled: true, width: 50 },
              { id: "darkMode", enabled: true, width: 50 }
            ]
          end
        )
        | map(
            if $ccWidgetOverrides[.id] != null then
              .enabled = $ccWidgetOverrides[.id]
            else
              .
            end
          )
      )
  '';

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
      ${pkgs.jq}/bin/jq \
        --arg theme "$HOME/.config/DankMaterialShell/themes/tokyo-night.json" \
        --argjson ccWidgetOverrides '${builtins.toJSON cfg.controlCenter.widgets}' \
        '
          .currentThemeName = "custom"
          | .customThemeFile = $theme
          | .cornerRadius = 12
          | .animationSpeed = 1
          | .dankBarTransparency = 0.35
          | .dankBarWidgetTransparency = 0.90
          | .innerPadding = 4

          # WorkVM weather.
          | .weatherEnabled = true
          | .useAutoLocation = true
          | .useFahrenheit = false

          # WorkVM clock.
          | .clockFormat = "24h"
          | .showSeconds = false
          | .clockDateFormat = "ddd dd.MM."

          ${controlCenterFilter}

          # Keep weather in the center and remove battery and DMS clipboard
          # widgets from existing DMS 1.6 WorkVM bar configurations.
          | if (.barConfigs | type) == "array" then
              .barConfigs |= map(
                if .id == "default" then
                  .innerPadding = 4
                  | .centerWidgets = (
                    ((.centerWidgets // []) | map(select(. != "weather")))
                    + ["weather"]
                  )
                  | .rightWidgets = (
                    (.rightWidgets // [])
                    | map(select(. != "battery" and . != "clipboard"))
                  )
                else
                  .
                end
              )
            else
              .
            end
        ' "$config_file" > "$tmp_file"
    else
      ${pkgs.jq}/bin/jq -n \
        --arg theme "$HOME/.config/DankMaterialShell/themes/tokyo-night.json" \
        --argjson ccWidgetOverrides '${builtins.toJSON cfg.controlCenter.widgets}' \
        '{
          currentThemeName: "custom",
          customThemeFile: $theme,
          cornerRadius: 12,
          animationSpeed: 1,
          dankBarTransparency: 0.12,
          dankBarWidgetTransparency: 0.82,

          weatherEnabled: true,
          useAutoLocation: true,
          useFahrenheit: false,

          clockFormat: "24h",
          showSeconds: false,
          clockDateFormat: "ddd dd.MM.",
          showWeather: true,

          showBattery: false
        }
        ${controlCenterFilter}
        ' > "$tmp_file"
    fi

    mv "$tmp_file" "$config_file"
    chmod 600 "$config_file"
  '';
  applyAlwaysOnPolicy = pkgs.writeShellScript "dms-apply-always-on-policy" ''
    config_dir="$HOME/.config/DankMaterialShell"
    config_file="$config_dir/settings.json"
    tmp_file="$config_file.tmp"

    mkdir -p "$config_dir"

    if [ -f "$config_file" ] && ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq '
        .acMonitorTimeout = 0
        | .acLockTimeout = 0
        | .acSuspendTimeout = 0
        | .acHibernateTimeout = 0
        | .acPostLockMonitorTimeout = 0
        | .batteryMonitorTimeout = 0
        | .batteryLockTimeout = 0
        | .batterySuspendTimeout = 0
        | .batteryHibernateTimeout = 0
        | .batteryPostLockMonitorTimeout = 0
        | .lockBeforeSuspend = false
      ' "$config_file" > "$tmp_file"

      mv "$tmp_file" "$config_file"
      chmod 600 "$config_file"
    fi
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
  options.hakkabara.desktop.dms = {
    controlCenter = {
      enable = lib.mkEnableOption "declarative DMS control-center configuration";

      icons = {
        network = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the network status icon in the DMS control center.";
        };

        bluetooth = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the Bluetooth status icon in the DMS control center.";
        };

        audio = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the audio status icon in the DMS control center.";
        };

        vpn = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the VPN status icon in the DMS control center.";
        };

        brightness = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Show the brightness status icon in the DMS control center.";
        };

        mic = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Show the microphone status icon in the DMS control center.";
        };

        battery = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Show the battery status icon in the DMS control center.";
        };

        screenSharing = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show the screen-sharing status icon in the DMS control center.";
        };
      };

      widgets = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = { };
        description = ''
          Enable or disable individual DMS control-center widgets by their
          upstream widget ID.
        '';
      };
    };

    alwaysOn.enable = lib.mkEnableOption "always-on DMS desktop policy";

    clipboardHistoryPersistence.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow DankMaterialShell to persist clipboard history to disk.";
    };
  };

  config = {
    xdg.configFile."DankMaterialShell/themes/tokyo-night.json".source = dmsTokyoNightTheme;

    home.activation = {
      dmsApplyTokyoNightTheme = lib.hm.dag.entryAfter [
        "writeBoundary"
      ] "${applyTokyoNightTheme}";

      dmsApplyAlwaysOnPolicy = lib.mkIf cfg.alwaysOn.enable (
        lib.hm.dag.entryAfter [
          "dmsApplyTokyoNightTheme"
        ] "${applyAlwaysOnPolicy}"
      );

      dmsDisableClipboardHistoryPersistence = lib.mkIf (!cfg.clipboardHistoryPersistence.enable) (
        lib.hm.dag.entryAfter [
          "dmsApplyTokyoNightTheme"
        ] "${disableClipboardPersistence}"
      );
    };
  };
}
