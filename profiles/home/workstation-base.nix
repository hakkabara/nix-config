{
  config,
  lib,
  ...
}:

{
  # Shared baseline for interactive workstation-like systems.
  #
  # mkDefault intentionally gives individual hosts the ability to override
  # these choices without requiring mkForce.
  hakkabara = {
    terminal.enable = lib.mkDefault true;
    cli.enable = lib.mkDefault true;
    shell.enable = lib.mkDefault true;

    editor.enable = lib.mkDefault true;

    git.enable = lib.mkDefault true;
    nixDev.enable = lib.mkDefault true;

    # Common Gecko extension baseline.
    #
    # Individual hosts may override any one of these with false.
    browsers.gecko.extensions = {
      uBlockOrigin.enable = lib.mkDefault true;
      darkReader.enable = lib.mkDefault true;
      violentmonkey.enable = lib.mkDefault true;
      bitwarden.enable = lib.mkDefault true;
      multiAccountContainers.enable = lib.mkDefault true;
      consentOMatic.enable = lib.mkDefault true;
      sponsorBlock.enable = lib.mkDefault true;
      enhancerForYouTube.enable = lib.mkDefault true;
    };

    # Shared workstation navigation.
    #
    # Use the Home Manager user's actual home directory instead of hard-coding
    # /home/hakkabara so the same profile also works for future users/VMs.
    cli.yazi.extraKeymap = [
      {
        on = [
          "g"
          "n"
        ];
        run = "cd ${config.home.homeDirectory}/nix-config";
        desc = "Go to Nix configuration";
      }
    ];
  };
}
