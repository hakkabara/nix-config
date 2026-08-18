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
}
