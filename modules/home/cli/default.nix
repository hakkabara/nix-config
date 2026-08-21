{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.cli;
in
{
  options.hakkabara.cli = {
    enable = lib.mkEnableOption "shared command-line tool environment";

    yazi.extraKeymap = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Additional Yazi manager keybindings supplied by profiles or hosts.";
    };
  };

  config = lib.mkIf cfg.enable {
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

        # Shared Yazi bindings live here.
        #
        # Profiles and individual hosts can append bindings through:
        #
        #   hakkabara.cli.yazi.extraKeymap
        #
        # This keeps universal behavior separate from machine-specific paths.
        keymap.mgr.prepend_keymap = [
          {
            on = [
              "g"
              "l"
            ];

            # lnav is an interactive TUI.  --block temporarily gives the
            # terminal to lnav and lets Yazi resume cleanly when lnav exits.
            #
            # lib.getExe resolves the exact lnav executable from our Nixpkgs
            # package instead of depending on an arbitrary PATH lookup.
            run = "shell --block -- ${lib.getExe pkgs.lnav} %h";
            desc = "Open hovered file in lnav";
          }
        ]
        ++ cfg.yazi.extraKeymap;
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
  };
}
