{ pkgs, ... }:

{
  programs = {
    firefox.enable = true;
    thunderbird.enable = true;
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
