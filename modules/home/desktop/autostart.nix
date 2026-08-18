{ pkgs, ... }:

{
  xdg.configFile = {
    "autostart/equibop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Equibop
      Comment=Start Equibop minimized
      Exec=${pkgs.equibop}/bin/equibop --start-minimized
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/obsidian.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Obsidian
      Comment=Start Obsidian
      Exec=${pkgs.obsidian}/bin/obsidian
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/thunderbird.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Thunderbird
      Comment=Start Thunderbird
      Exec=${pkgs.thunderbird}/bin/thunderbird
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/signal.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Comment=Start Signal in the system tray
      Exec=${pkgs.signal-desktop}/bin/signal-desktop --use-tray-icon --start-in-tray
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/telegram.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Telegram
      Comment=Start Telegram in the system tray
      Exec=${pkgs.telegram-desktop}/bin/telegram-desktop -startintray -autostart
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';
    "autostart/bitwarden.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Bitwarden
      Comment=Start Bitwarden
      Exec=${pkgs.bitwarden-desktop}/bin/bitwarden
      Icon=bitwarden
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';
  };
}
