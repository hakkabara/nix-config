{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font Mono";
      size = 12;
    };

    shellIntegration.enableZshIntegration = true;

    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
    };
  };
}
