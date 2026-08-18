{ pkgs, ... }:

{
  programs = {
    firefox.enable = true;

    thunderbird = {
      enable = true;

      languagePacks = [
        "de"
      ];

      policies = {
        DisableTelemetry = true;
        DisableAppUpdate = true;
      };
    };
  };
  xdg = {
    mimeApps = {
      enable = true;

      associations.added = {
        "x-scheme-handler/obsidian" = "obsidian.desktop";
      };

      defaultApplications = {
        # Web
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

        # Obsidian
        "x-scheme-handler/obsidian" = "obsidian.desktop";
      };
    };

    # Some desktop applications rewrite mimeapps.list themselves.
    # Nix/Home Manager is intentionally the source of truth here.
    configFile."mimeapps.list".force = true;
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
