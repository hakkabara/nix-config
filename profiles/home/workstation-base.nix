{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./cli.nix
  ];

  home.packages = [
    pkgs.libnotify
  ];

  # Shared baseline for interactive workstation-like systems.
  #
  # mkDefault intentionally gives individual hosts the ability to override
  # these choices without requiring mkForce.
  hakkabara = {
    terminal.enable = lib.mkDefault true;

    apps.flameshot.enable = lib.mkDefault true;

    editor.enable = lib.mkDefault true;

    nixDev.enable = lib.mkDefault true;

    # Common Gecko browser baseline.
    #
    # These extensions and the Tokyo Night browser rice are useful on
    # every workstation. Hosts can override each mkDefault individually.
    browsers.gecko.extensions = {
      uBlockOrigin.enable = lib.mkDefault true;
      consentOMatic.enable = lib.mkDefault true;
      darkReader.enable = lib.mkDefault true;
      tokyoNightTheme.enable = lib.mkDefault true;
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
