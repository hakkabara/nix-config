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

    # Common Gecko extension baseline.
    #
    # Individual hosts may override any one of these with false.
    browsers.gecko.extensions = {
      uBlockOrigin.enable = lib.mkDefault true;
      darkReader.enable = lib.mkDefault true;
      violentmonkey.enable = lib.mkDefault true;

      # Violentmonkey is deny-by-default. Individual hosts must
      # explicitly allow every origin on which userscripts may
      # execute or communicate.
      violentmonkey.firefox.runtimeBlockedHosts = lib.mkDefault [
        "*://*"
      ];
      bitwarden.enable = lib.mkDefault true;
      multiAccountContainers.enable = lib.mkDefault true;
      consentOMatic.enable = lib.mkDefault true;
      sponsorBlock = {
        enable = lib.mkDefault true;

        firefox = {
          runtimeBlockedHosts = lib.mkDefault [
            "*://*"
          ];

          runtimeAllowedHosts = lib.mkDefault [
            "https://*.youtube.com"
            "https://www.youtube-nocookie.com"
            "https://sponsor.ajay.app"
          ];
        };
      };

      enhancerForYouTube = {
        enable = lib.mkDefault true;

        firefox = {
          runtimeBlockedHosts = lib.mkDefault [
            "*://*"
          ];

          runtimeAllowedHosts = lib.mkDefault [
            "https://www.youtube.com"
          ];
        };
      };
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
