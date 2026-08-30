{
  lib,
  ...
}:

{
  imports = [
    ./workstation-base.nix
    ../../modules/home/desktop/niri
  ];

  hakkabara = {
    apps = {
      keepassxc.enable = lib.mkDefault true;
      copyq.enable = lib.mkDefault true;
      obsidian.enable = lib.mkDefault true;
      signal.enable = lib.mkDefault true;
    };

    browsers = {
      gecko = {
        firefox = {
          enable = lib.mkDefault true;
          profileName = lib.mkDefault "work";
          profileDisplayName = lib.mkDefault "Work";
          profileId = lib.mkDefault 0;
        };

        floorp = {
          enable = lib.mkDefault true;
          profileName = lib.mkDefault "work";
          profileDisplayName = lib.mkDefault "Work";
          profileId = lib.mkDefault 0;
          whatsappProfile.enable = lib.mkDefault false;
        };
      };

      chromium = {
        chromium.enable = lib.mkDefault true;
        googleChrome.enable = lib.mkDefault true;
        vivaldi.enable = lib.mkDefault true;
      };
    };

    # WorkVM Wayland compositor configuration.
    #
    # DMS itself is intentionally configured at the NixOS level through the
    # native programs.dms-shell module available in NixOS 26.05.
    desktop.niri = {
      enable = lib.mkDefault true;
      # Keep DMS IPC shortcuts in the generated Niri configuration.
      dmsIntegration.enable = lib.mkDefault true;
    };
  };
}
