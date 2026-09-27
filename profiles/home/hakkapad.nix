{ ... }:

{
  # Native private workstation:
  #
  # personal-workstation:
  #   private apps, browsers, bookmarks, SSH, AI, theme
  #
  # niri-workstation:
  #   shared Niri/DMS session, keybindings and rice
  imports = [
    ./personal-workstation.nix
    ./niri-workstation.nix
  ];

  hakkabara.desktop.niri.touchpad = {
    enable = true;

    tap = true;
    naturalScroll = true;

    # Avoid accidental palm movement while typing or using the TrackPoint.
    disableWhileTyping = true;
    disableWhileTrackpointing = true;

    # Keep libinput neutral until the physical touchpad has been tested.
    accelSpeed = 0.0;
  };

  hakkabara.desktop.dms = {
    # Unlike the WorkVM, a physical laptop must retain normal
    # lock/idle/power-management behavior.
    alwaysOn.enable = false;

    bar.battery = {
      enable = true;
      showPercent = true;
    };

    powerPolicy = {
      enable = true;

      # DMS integrates with login1 PrepareForSleep, so lid-triggered
      # and manually requested suspend both lock the session first.
      lockBeforeSuspend = true;

      # Keep normal performance during normal battery use and only
      # switch to Power Saver when the battery reaches DMS' low threshold.
      autoPowerSaver = true;

      ac = {
        monitorTimeout = 600;
        lockTimeout = 600;
        suspendTimeout = 3600;
        postLockMonitorTimeout = 30;
        profile = "balanced";
      };

      battery = {
        monitorTimeout = 300;
        lockTimeout = 300;
        suspendTimeout = 1200;
        postLockMonitorTimeout = 30;
        profile = "balanced";
      };
    };
  };
}
