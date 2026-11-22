{
  config,
  lib,
  ...
}:

{
  imports = [
    ./workstation-base.nix
    ../../modules/home/desktop/dms
    ../../modules/home/desktop/niri
    ../../modules/home/desktop/file-chooser-pins.nix
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
        extensions.foxyProxy = {
          enable = lib.mkDefault true;
          settings = {
            enable = lib.mkDefault true;
            # Keep the proxy list as import file, but leave the FoxyProxy
            # UI editable so the mode can be switched with the mouse.
            lockViaPolicy = lib.mkDefault false;
          };
        };

        # Gecko ignores the system trust store on Linux; trust the internal
        # deployment-LAN CA (HTTPS for git.deploy.internal) explicitly.
        overrides.common.policies.Certificates.Install = [
          "${../../keys/deploy-lan-ca.crt}"
        ];

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

          # Native Wayland: under xwayland-satellite, Floorp popups
          # (menus, dropdowns, extension panels) do not take clicks.
          # Trade-off: the Wayland/EGL path renders in software on
          # VMware SVGA.
          graphics.xwaylandGlx.enable = lib.mkDefault false;
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
    desktop = {
      # DMS itself is intentionally configured at the NixOS level through the
      # native programs.dms-shell module available in NixOS 26.05.
      dms.clipboardHistoryPersistence.enable = lib.mkDefault false;

      niri = {
        enable = lib.mkDefault true;
        # Keep DMS IPC shortcuts in the generated Niri configuration.
        dmsIntegration.enable = lib.mkDefault true;
      };

      # Sidebar of the Open/Save dialog (xdg-desktop-portal). Extend the list
      # here or from another module; customer folders come with customer.
      fileChooserPins = {
        enable = lib.mkDefault true;
        pins = [
          {
            path = "/data/nfs/llm";
            label = "LLM (NFS)";
          }
          {
            path = "/data/share/clean";
            label = "Share clean";
          }
          {
            path = "/data/share/unclean";
            label = "Share unclean";
          }
          {
            path = config.xdg.userDirs.download;
            label = "Downloads";
          }
        ];
      };
    };
  };
}
