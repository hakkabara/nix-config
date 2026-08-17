{ ... }:

{
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;

      autosuggestion = {
        enable = true;

        strategy = [
          "history"
          "completion"
        ];
      };

      syntaxHighlighting.enable = true;

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
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
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
        "nerd-font-symbols"
      ];

      settings = {
        add_newline = false;
        command_timeout = 1000;

        directory = {
          truncation_length = 4;
          truncate_to_repo = false;
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };
    };
  };
}
