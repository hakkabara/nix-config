{ config, pkgs, ... }:

{
  xdg.configFile = {
    "autostart/equibop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Equibop
      Comment=Start Equibop
      Exec=${pkgs.equibop}/bin/equibop
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

    "autostart/whatsapp-floorp.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=WhatsApp
      Comment=Start WhatsApp in an isolated Floorp profile
      Exec=${config.programs.floorp.finalPackage}/bin/floorp -P WhatsApp --new-instance --new-window https://web.whatsapp.com/
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/element.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Element
      Comment=Start Element
      Exec=${pkgs.element-desktop}/bin/element-desktop
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/signal.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Comment=Start Signal with tray support
      Exec=${pkgs.signal-desktop}/bin/signal-desktop --use-tray-icon
      Terminal=false
      Hidden=false
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
    '';

    "autostart/telegram.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Telegram
      Comment=Start Telegram
      Exec=${pkgs.telegram-desktop}/bin/Telegram
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
