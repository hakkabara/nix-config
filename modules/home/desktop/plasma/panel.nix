{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.desktop.plasma;
in
{
  options.hakkabara.desktop.plasma.panel = {
    enable = lib.mkEnableOption "managed clean Plasma panel";

    launchers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
      ];
      description = "Application desktop IDs pinned to Plasma's Icons-Only Task Manager.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.panel.enable) {
    programs.plasma.panels = [
      {
        # Clean floating bottom panel.
        #
        # Layout:
        #
        # [Launcher] [Pinned Apps] ........ [Tray] [Clock]
        #
        location = "bottom";
        height = 38;
        floating = true;
        hiding = "none";
        opacity = "adaptive";

        widgets = [
          # Plasma application launcher.
          "org.kde.plasma.kickoff"

          # Compact i3/Niri-style virtual desktop indicator.
          {
            name = "org.kde.plasma.virtualdesktopbar";

            config = {
              Behavior = {
                DynamicDesktops = false;
                FilterByScreen = false;

                # Safe mouse behavior: scrolling switches desktops but
                # middle-click can never accidentally remove one.
                WheelScrollSwitches = true;
                WheelClickRemoves = false;
                WheelWrapAround = false;
              };

              Appearance = {
                AnimationsEnable = false;
                TooltipsEnable = true;
                ShowAddButton = false;

                ButtonMarginVertical = 2;
                ButtonMarginHorizontal = 2;
                ButtonSpacing = 2;
                ButtonCommonSize = true;

                # Upstream index 1 = desktop number.
                LabelStyle = 1;
                LabelDimIdle = true;
                LabelBoldCurrent = true;

                # Upstream index 3 = rounded indicator.
                IndicatorStyle = 3;

                # Inherit colors from Tokyo Night rather than hard-coding
                # another palette into the widget.
                IndicatorDistinctOccupied = true;
                IndicatorDistinctAttention = true;
              };
            };
          }

          # Icons-only task manager.
          {
            iconTasks = {
              launchers = cfg.panel.launchers;
            };
          }

          # Spacer.
          "org.kde.plasma.marginsseparator"

          # Clean system tray.
          {
            systemTray.items = {

              # Always visible.
              shown = [
                "org.kde.plasma.networkmanagement"
                "org.kde.plasma.volume"
                "org.kde.plasma.notifications"
              ];

              # Hidden behind tray arrow.
              hidden = [
                # Clipboard manager replaced later.
                "org.kde.plasma.clipboard"

                # VM: no battery/brightness.
                "org.kde.plasma.battery"
                "org.kde.plasma.brightness"

                # Rarely needed.
                "org.kde.plasma.devicenotifier"
                "org.kde.plasma.weather"
                "org.kde.plasma.printmanager"
                "org.kde.kscreen"
                "org.kde.plasma.keyboardindicator"
                "org.kde.plasma.keyboardlayout"
                "org.kde.plasma.manage-inputmethod"
                "org.kde.plasma.cameraindicator"
                "org.kde.plasma.mediacontroller"

                # Applications.
                "org.telegram.desktop"
                "org.equicord.equibop.StatusNotifierItem"
              ];
            };
          }

          {
            digitalClock = {
              date.enable = false;
              time.format = "24h";
              calendar.firstDayOfWeek = "monday";
            };
          }
        ];
      }
    ];
  };
}
