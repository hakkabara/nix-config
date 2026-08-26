{ pkgs, ... }:

{
  home.packages = [
    pkgs.flameshot
  ];

  # Dedicated desktop entry so KGlobalAccel launches "flameshot gui"
  # instead of the normal Flameshot tray application.
  xdg.desktopEntries.flameshot-gui = {
    name = "Flameshot GUI";
    exec = "${pkgs.flameshot}/bin/flameshot gui";
    icon = "flameshot";
    terminal = false;
    noDisplay = true;
    startupNotify = false;

    settings = {
      X-KDE-GlobalAccel-CommandShortcut = "true";
    };
  };

  programs.plasma = {
    spectacle.shortcuts = {
      captureActiveWindow = [ ];
      captureCurrentMonitor = [ ];
      captureEntireDesktop = [ ];
      captureRectangularRegion = [ ];
      captureWindowUnderCursor = [ ];
      launch = [ ];
      launchWithoutCapturing = [ ];
      recordRegion = [ ];
      recordScreen = [ ];
      recordWindow = [ ];
    };

    shortcuts = {
      "services/flameshot-gui.desktop"."_launch" = "Meta+Shift+S";

      # Explicitly remove the shortcut from the regular Flameshot launcher.
      "services/org.flameshot.Flameshot.desktop"."_launch" = [ ];
    };
  };

  # Start the Flameshot daemon/tray at login so the first capture is immediate.
  xdg.configFile."autostart/flameshot.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Flameshot
    Exec=${pkgs.flameshot}/bin/flameshot
    Icon=flameshot
    Terminal=false
    X-KDE-autostart-after=panel
  '';
}
