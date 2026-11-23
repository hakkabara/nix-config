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

  barFollow = pkgs.writeShellApplication {
    name = "dms-bar-follow";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    # niri comes from the session PATH (same binary as the compositor).
    text = builtins.readFile ./bar-follow.sh;
  };

  applyTokyoNightTheme = pkgs.writeShellScript "dms-apply-tokyo-night-theme" ''
    config_dir="$HOME/.config/DankMaterialShell"
    config_file="$config_dir/settings.json"
    tmp_file="$config_file.tmp"

    mkdir -p "$config_dir"

    if [ -f "$config_file" ] && ${pkgs.jq}/bin/jq empty "$config_file" >/dev/null 2>&1; then
      ${pkgs.jq}/bin/jq \
        --arg theme "$HOME/.config/DankMaterialShell/themes/tokyo-night.json" \
        --argjson ccWidgetOverrides '${builtins.toJSON cfg.controlCenter.widgets}' \
        --argjson vpnWidget ${lib.boolToString cfg.bar.vpnWidget.enable} \
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
          # widgets from existing DMS 1.6 WorkVM bar configurations. The VPN
          # widget (status and connect menu) sits first on the right.
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
                    | map(select(
                        (if type == "string" then . else .id end) as $id
                        | $id != "battery" and $id != "clipboard" and $id != "vpn"
                      ))
                    | (if $vpnWidget then ["vpn"] + . else . end)
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
  # Git-managed wallpapers, same store-backed layout as the Plasma rice
  # module (one symlink per image, so a changed image gets a new path).
  wallpaperSource = ../../../../assets/wallpapers;
  wallpaperDir = "${config.xdg.dataHome}/wallpapers/nix-config";

  # DMS has no separate "wallpaper folder" setting: the wallpaper picker
  # opens the folder of the current wallpaper, cycling uses its own folder.
  # Point both at the managed folder, but only where nothing is set yet (or
  # the chosen file no longer exists), so a selection made in DMS survives.
  # DMS watches session.json and reloads it while running.
  applyWallpaperDefaults = pkgs.writeShellScript "dms-apply-wallpaper-defaults" ''
    session_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/dms"
    session_file="$session_dir/session.json"
    tmp_file="$session_file.tmp"
    default_wallpaper=${lib.escapeShellArg "${wallpaperDir}/${cfg.wallpapers.default}"}
    wallpaper_dir=${lib.escapeShellArg wallpaperDir}

    mkdir -p "$session_dir"

    if [ -f "$session_file" ]; then
      ${pkgs.jq}/bin/jq empty "$session_file" >/dev/null 2>&1 || {
        echo "dms: session.json is not valid JSON, wallpaper defaults skipped" >&2
        exit 0
      }
      current="$(${pkgs.jq}/bin/jq -r '.wallpaperPath // ""' "$session_file")"
    else
      echo '{}' > "$session_file"
      current=""
    fi

    set_wallpaper=false
    if [ -z "$current" ] || { [ "''${current#/}" != "$current" ] && [ ! -e "$current" ]; }; then
      set_wallpaper=true
    fi

    ${pkgs.jq}/bin/jq \
      --arg wallpaper "$default_wallpaper" \
      --arg dir "$wallpaper_dir" \
      --argjson setWallpaper "$set_wallpaper" \
      '
        (if $setWallpaper then .wallpaperPath = $wallpaper else . end)
        | (if ((.wallpaperCyclingFolderPath // "") == "") then .wallpaperCyclingFolderPath = $dir else . end)
      ' "$session_file" > "$tmp_file"

    mv "$tmp_file" "$session_file"
    chmod 600 "$session_file"
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
    bar.mainOutputOnly = {
      enable = lib.mkEnableOption ''
        a mirrored DMS bar on secondary monitors without the listed widgets.
        The main monitor is the active output with the most pixels, so the
        assignment survives VMware swapping Virtual-1 and Virtual-2
      '';

      widgets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "music" ];
        description = "DMS bar widget ids shown only on the main monitor.";
      };
    };

    bar.vpnWidget.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Show the DMS VPN widget in the bar: current VPN state and a menu to
        connect or disconnect NetworkManager VPN profiles.
      '';
    };

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

    wallpapers = {
      enable = lib.mkEnableOption "Nix-managed DMS wallpaper folder (assets/wallpapers)";

      default = lib.mkOption {
        type = lib.types.str;
        default = "kde-neon-rain-4k.png";
        description = ''
          File in assets/wallpapers used as wallpaper while DMS has none
          selected (or the selected file is gone). A choice made in DMS is
          kept.
        '';
      };
    };

    clipboardHistoryPersistence.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow DankMaterialShell to persist clipboard history to disk.";
    };
  };

  config = {
    assertions = [
      {
        assertion =
          !cfg.wallpapers.enable || builtins.pathExists (wallpaperSource + "/${cfg.wallpapers.default}");
        message = "hakkabara.desktop.dms.wallpapers.default must name a file in assets/wallpapers.";
      }
    ];

    xdg.configFile."DankMaterialShell/themes/tokyo-night.json".source = dmsTokyoNightTheme;

    xdg.dataFile."wallpapers/nix-config" = lib.mkIf cfg.wallpapers.enable {
      source = wallpaperSource;
      recursive = true;
    };

    systemd.user.services.dms-bar-follow = lib.mkIf cfg.bar.mainOutputOnly.enable {
      Unit = {
        Description = "Keep the DMS main bar on the largest monitor";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = lib.getExe barFollow;
        Environment = [
          "DMS_BAR_MAIN_ONLY_WIDGETS=${lib.concatStringsSep "," cfg.bar.mainOutputOnly.widgets}"
        ];
        Restart = "always";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    home.activation = {
      dmsApplyTokyoNightTheme = lib.hm.dag.entryAfter [
        "writeBoundary"
      ] "${applyTokyoNightTheme}";

      dmsApplyAlwaysOnPolicy = lib.mkIf cfg.alwaysOn.enable (
        lib.hm.dag.entryAfter [
          "dmsApplyTokyoNightTheme"
        ] "${applyAlwaysOnPolicy}"
      );

      dmsApplyWallpaperDefaults = lib.mkIf cfg.wallpapers.enable (
        lib.hm.dag.entryAfter [
          "linkGeneration"
        ] "${applyWallpaperDefaults}"
      );

      dmsDisableClipboardHistoryPersistence = lib.mkIf (!cfg.clipboardHistoryPersistence.enable) (
        lib.hm.dag.entryAfter [
          "dmsApplyTokyoNightTheme"
        ] "${disableClipboardPersistence}"
      );
    };
  };
}
