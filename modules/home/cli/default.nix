{ pkgs, ... }:

{
  programs = {
    # Better cat-like viewer.
    # Keep the real `cat` command unchanged.
    bat.enable = true;

    # Modern interactive replacement for ls.
    eza = {
      enable = true;
      enableZshIntegration = true;

      icons = "auto";
      colors = "auto";
      git = true;

      extraOptions = [
        "--group-directories-first"
      ];
    };

    # Terminal file manager.
    yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    # System monitor.
    btop.enable = true;

    # Git TUI.
    lazygit = {
      enable = true;
      enableZshIntegration = true;
    };

    # Better Git diff rendering.
    delta = {
      enable = true;
      enableGitIntegration = true;

      options = {
        navigate = true;
        line-numbers = true;
      };
    };
  };

  home.packages = with pkgs; [
    # Search
    ripgrep
    fd

    # Structured data
    jq
    yq-go

    # Files / navigation
    tree
    file
    less

    # Disk usage
    duf
    dust

    # Processes / logs
    procs

    # Git / GitHub
    gh

    # HTTP / networking
    curl
    wget
    xh
    miniserve
    speedtest-go

    # File transfer / sync
    rsync
    rclone

    # Archives
    unzip
    _7zz
    ouch

    # Documentation / benchmarking
    tealdeer
    hyperfine
  ];
}
