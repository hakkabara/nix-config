{
  config,
  lib,
  pkgs,
  plasma-manager,
  ...
}:

let
  cfg = config.hakkabara.desktop.plasma;

  # Plasma has separate AC/battery/low-battery profiles.
  # For an always-on VM they should all behave identically.
  alwaysOnPowerProfile = {
    autoSuspend.action = "nothing";

    turnOffDisplay.idleTimeout = "never";

    dimDisplay.enable = false;
  };
in
{
  # plasma-manager provides the programs.plasma.* options used below.
  imports = [
    plasma-manager.homeModules.plasma-manager
  ];

  options.hakkabara.desktop.plasma = {
    enable = lib.mkEnableOption "managed KDE Plasma user configuration";

    # Deliberately OFF by default.
    #
    # Enabling Plasma must never implicitly mean that a machine no longer
    # locks its screen or saves power.
    alwaysOn.enable = lib.mkEnableOption "always-on Plasma desktop policy";

    # Deliberately OFF by default.
    #
    # Provides our keyboard-driven, i3-inspired Plasma workflow without
    # forcing these bindings onto every Plasma system using this module.
    i3Style.enable = lib.mkEnableOption "i3-inspired Plasma keyboard workflow";

    # Deliberately OFF by default.
    #
    # Start Plasma without restoring windows/applications from the
    # previous login session.
    emptySession.enable = lib.mkEnableOption "start Plasma with an empty session";

    # Deliberately OFF by default.
    #
    # Allow XWayland applications to emulate pointer/keyboard input without
    # showing KWin's recurring "Remote Control" permission dialog.
    xwaylandInputNoPrompt.enable = lib.mkEnableOption "allow XWayland input emulation without permission prompts";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.plasma.enable = true;
      }

      (lib.mkIf cfg.alwaysOn.enable {
        programs.plasma = {
          # Manual locking is still possible. We only disable automatic
          # locking and lock-on-resume/startup.
          kscreenlocker = {
            autoLock = false;
            lockOnResume = false;
            lockOnStartup = false;
          };

          # Prevent Plasma/PowerDevil from dimming, switching the display off,
          # or requesting automatic suspend.
          powerdevil = {
            AC = alwaysOnPowerProfile;
            battery = alwaysOnPowerProfile;
            lowBattery = alwaysOnPowerProfile;
          };
        };
      })

      (lib.mkIf cfg.emptySession.enable {
        programs.plasma.configFile.ksmserverrc.General.loginMode = "emptySession";
      })

      (lib.mkIf cfg.xwaylandInputNoPrompt.enable {
        programs.plasma.configFile.kwinrc.Xwayland.XwaylandEisNoPrompt = true;
      })

      (lib.mkIf cfg.i3Style.enable {
        programs.plasma = {
          # Keep ten workspaces in one linear row.
          #
          # Meta+1..9 selects desktops 1..9 and Meta+0 selects desktop 10.
          kwin.virtualDesktops = {
            number = 10;
            rows = 1;
          };

          shortcuts = {
            # Meta+L is needed for directional focus, so move the manual
            # screen-lock shortcut to Meta+Ctrl+L while preserving a physical
            # Screensaver key if the keyboard provides one.
            ksmserver = {
              "Lock Session" = [
                "Meta+Ctrl+L"
                "Screensaver"
              ];
            };

            kwin = {
              # Meta+D is reassigned to Plasma's application launcher.
              "Show Desktop" = [ ];

              # Meta+0 is used for desktop 10 rather than KWin's zoom
              # "actual size" action.
              "view_actual_size" = [ ];

              # i3/Vim-style directional window focus.
              "Switch Window Left" = "Meta+H";
              "Switch Window Down" = "Meta+J";
              "Switch Window Up" = "Meta+K";
              "Switch Window Right" = "Meta+L";

              # Direct workspace switching.
              "Switch to Desktop 1" = "Meta+1";
              "Switch to Desktop 2" = "Meta+2";
              "Switch to Desktop 3" = "Meta+3";
              "Switch to Desktop 4" = "Meta+4";
              "Switch to Desktop 5" = "Meta+5";
              "Switch to Desktop 6" = "Meta+6";
              "Switch to Desktop 7" = "Meta+7";
              "Switch to Desktop 8" = "Meta+8";
              "Switch to Desktop 9" = "Meta+9";
              "Switch to Desktop 10" = "Meta+0";

              # Move the active window directly to a workspace.
              "Window to Desktop 1" = "Meta+!";
              "Window to Desktop 2" = "Meta+@";
              "Window to Desktop 3" = "Meta+#";
              "Window to Desktop 4" = "Meta+$";
              "Window to Desktop 5" = "Meta+%";
              "Window to Desktop 6" = "Meta+^";
              "Window to Desktop 7" = "Meta+&";
              "Window to Desktop 8" = "Meta+*";
              "Window to Desktop 9" = "Meta+(";
              "Window to Desktop 10" = "Meta+)";

              # Common window operations.
              "Window Fullscreen" = "Meta+F";
              "Window Maximize" = "Meta+M";
              "Window Close" = "Meta+Shift+Q";
            };

            # KRunner is Plasma's compact search/application runner.
            # Keep its standard shortcuts and add Meta+D.
            "services/org.kde.krunner.desktop" = {
              "_launch" = [
                "Search"
                "Alt+Space"
                "Alt+F2"
                "Meta+D"
              ];
            };

            plasmashell = {
              # Preserve Plasma's standard launcher bindings and add Meta+D.
              "activate application launcher" = [
                "Meta"
                "Alt+F1"
              ];

              # Meta+number is reserved for virtual desktops rather than
              # activating pinned Task Manager entries.
              "activate task manager entry 1" = [ ];
              "activate task manager entry 2" = [ ];
              "activate task manager entry 3" = [ ];
              "activate task manager entry 4" = [ ];
              "activate task manager entry 5" = [ ];
              "activate task manager entry 6" = [ ];
              "activate task manager entry 7" = [ ];
              "activate task manager entry 8" = [ ];
              "activate task manager entry 9" = [ ];
              "activate task manager entry 10" = [ ];
            };
          };

          # Starting an application is not a KWin window-management action.
          # plasma-manager therefore creates a dedicated global command hotkey.
          hotkeys.commands."launch-kitty" = {
            name = "Launch Kitty";
            key = "Meta+Return";
            command = lib.getExe pkgs.kitty;

            # Kitty does not need its stdout/stderr wrapped by systemd-cat.
            logs.enabled = false;
          };
        };
      })
    ]
  );
}
