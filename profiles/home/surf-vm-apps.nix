{ pkgs, ... }:

{
  # SurfVM-specific application selection.
  #
  # Some of these modules are still unconditional legacy modules.
  # They live here temporarily so importing the shared app registry
  # no longer installs SurfVM applications on every Home Manager host.
  #
  # They can later be converted to reusable enable-based app modules.
  imports = [
    ../../modules/home/apps/equibop.nix
    ../../modules/home/apps/copyq
    ../../modules/home/apps/immich
    ../../modules/home/apps/veracrypt.nix
    ../../modules/home/apps/element.nix
  ];

  programs.thunderbird = {
    enable = true;

    languagePacks = [
      "de"
    ];

    policies = {
      DisableTelemetry = true;
      DisableAppUpdate = true;
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
        "text/html" = "floorp.desktop";
        "application/xhtml+xml" = "floorp.desktop";
        "x-scheme-handler/http" = "floorp.desktop";
        "x-scheme-handler/https" = "floorp.desktop";

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
    # Password manager
    bitwarden-desktop

    # Notes / knowledge
    obsidian

    # Communication
    signal-desktop
    telegram-desktop

    # Media
    spotify
    jellyfin-desktop

    # Documents / reading
    libreoffice-qt-fresh
    kdePackages.okular
    koreader
  ];
}
