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
