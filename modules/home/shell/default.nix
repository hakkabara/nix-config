{ config, lib, pkgs, ... }:

let
  cfg = config.hakkabara.shell;
in
{
  imports = [ ./network-tools.nix ];

  options.hakkabara.shell.enable = lib.mkEnableOption "shared interactive shell environment";

  config = lib.mkIf cfg.enable {
    programs = {
      zsh = {
        enable = true;
        enableCompletion = true;

        initContent = ''
          export PATH="$HOME/.local/bin:$PATH"
        '';

        autosuggestion = {
          enable = true;

          strategy = [
            "history"
            "completion"
          ];
        };

        syntaxHighlighting.enable = true;

        plugins = [
          {
            name = "zsh-completions";
            src = pkgs.zsh-completions;
          }

          {
            name = "fzf-tab";
            src = pkgs.fetchFromGitHub {
              owner = "Aloxaf";
              repo = "fzf-tab";
              rev = "v1.2.0";
              hash = "sha256-1ojmr9+Wg5+X5Dip4sKjP4IKKACMncPQDZ8RtYQSQ80=";
            };
          }

          {
            name = "alias-tips";
            src = pkgs.fetchFromGitHub {
              owner = "djui";
              repo = "alias-tips";
              rev = "41cb143ccc3b8cc444bf20257276cb43275f65c4";
              hash = "sha256-ZFWrwcwwwSYP5d8k7Lr/hL3WKAZmgn51Q9hYL3bq9vE=";
            };
          }

          {
            name = "zsh-you-should-use";
            src = pkgs.fetchFromGitHub {
              owner = "MichaelAquilina";
              repo = "zsh-you-should-use";
              rev = "5f3d129864ee4505043d88c3486224f1d75b692e";
              hash = "sha256-1ojmr9+Wg5+X5Dip4sKjP4IKKACMncPQDZ8RtYQSQ80=";
            };
          }
        ];

        history = {
          size = 100000;
          save = 100000;

          append = true;
          share = true;
          ignoreDups = true;
          ignoreAllDups = true;
          saveNoDups = true;
          findNoDups = true;
          ignoreSpace = true;

          expireDuplicatesFirst = true;
          extended = true;
        };

        historySubstringSearch.enable = true;

        autocd = true;
        defaultKeymap = "emacs";

        setOptions = [
          "HIST_VERIFY"
          "INTERACTIVE_COMMENTS"
          "AUTO_PUSHD"
          "PUSHD_IGNORE_DUPS"
          "PUSHD_SILENT"
        ];

        shellAliases = {
          # Navigation
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";

          # Git
          gs = "git status";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gl = "git log --oneline --graph --decorate";
          gd = "git diff";
          gco = "git checkout";
          gb = "git branch";

          # Nix
          nrs = "sudo nixos-rebuild switch --flake .";
          nrt = "sudo nixos-rebuild test --flake .";
          nfc = "nix flake check";
          nfu = "nix flake update";

          # Docker
          d = "docker";
          dc = "docker compose";
          dps = "docker ps";
          dpsa = "docker ps -a";
          di = "docker images";
          dex = "docker exec -it";
          dlog = "docker logs -f";

          # Docker Compose
          dcu = "docker compose up -d";
          dcd = "docker compose down";
          dcr = "docker compose restart";
          dcl = "docker compose logs -f";

          # Tools
          ll = "eza -lah";
          la = "eza -la";
          disk = "duf";
          usage = "dust";

          # Network / Debug
          ports = "ss -tulpn";
          journal = "journalctl -xe";

          # Kitty
          kssh = "kitten ssh";
          icat = "kitten icat";
        };
      };

      fzf = {
        enable = true;
        enableZshIntegration = true;

        defaultCommand = "fd --type f --hidden --follow --exclude .git";
        fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
        changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";

        defaultOptions = [
          "--height=40%"
          "--layout=reverse"
          "--border"
        ];
      };

      zoxide = {
        enable = true;
        enableZshIntegration = true;
      };

      direnv = {
        enable = true;
        enableZshIntegration = true;

        nix-direnv.enable = true;
      };

      starship = {
        enable = true;
        enableZshIntegration = true;

        presets = [
          "tokyo-night"
        ];

        settings = {
          add_newline = false;
          command_timeout = 1000;

          # Starship 1.25.1 hard-codes an Apple glyph in the Tokyo Night preset.
          # Keep the official layout/colors and replace only that segment with
          # the NixOS glyph.
          format = "[░▒▓](#a3aed2)[  ](bg:#a3aed2 fg:#090c0c)[](bg:#769ff0 fg:#a3aed2)$directory[](fg:#769ff0 bg:#394260)$git_branch$git_status[](fg:#394260 bg:#212736)$nodejs$bun$rust$golang$php[](fg:#212736 bg:#1d2230)$time[ ](fg:#1d2230)\n$character";
        };
      };
    };
  };
}
