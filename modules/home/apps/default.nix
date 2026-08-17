{ pkgs, ... }:

{
  programs = {
    firefox.enable = true;
    thunderbird.enable = true;
  };

  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # web
      "text/html" = "vivaldi-stable.desktop";
      "application/xhtml+xml" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      # PDF
      "application/pdf" = "org.kde.okular.desktop";

      # E-Books
      "application/epub+zip" = "koreader.desktop";

      # E-Mail
      "x-scheme-handler/mailto" = "thunderbird.desktop";
      "message/rfc822" = "thunderbird.desktop";
    };
  };

  home.packages = with pkgs; [
    # Browser
    vivaldi

    # Password manager
    bitwarden-desktop

    # Notes / knowledge
    obsidian

    # Communication
    signal-desktop
    telegram-desktop
    equibop

    # Media
    spotify
    jellyfin-desktop

    # Documents / reading
    libreoffice-qt-fresh
    kdePackages.okular
    koreader

    # Development / AI
    claude-code
  ];
}
