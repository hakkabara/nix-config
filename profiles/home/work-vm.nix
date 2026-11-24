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
    # `timer 25m …` reminders and local `meeting` notes (~/Notes/meetings).
    cli.workHelpers = {
      timer.enable = lib.mkDefault true;
      meeting.enable = lib.mkDefault true;
    };

    # Every host of the SSH config shows up in sshelf without a manual
    # `sshelf-import-ssh`.
    cli.sshelf.autoImport.enable = lib.mkDefault true;

    apps = {
      keepassxc.enable = lib.mkDefault true;
      copyq.enable = lib.mkDefault true;
      obsidian.enable = lib.mkDefault true;
      signal.enable = lib.mkDefault true;
      # `tk` / Mod+Shift+T: Glove80 TailorKey layer overview.
      tailorkey.enable = lib.mkDefault true;
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

          # Bookmarks toolbar always visible instead of hover-to-reveal.
          bookmarksBar.autoHide = lib.mkDefault false;

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
        # Borders follow the wallpaper palette whenever the shell does.
        dmsIntegration.matugenColors = lib.mkDefault (config.hakkabara.desktop.dms.theme == "dynamic");

        # Two monitors side by side: the window under the pointer has the
        # focus as in i3, and Mod+Left/Right walk from one monitor to the
        # other. The pointer follows a keyboard focus change, otherwise it
        # would pull the focus back to where it still is.
        focusFollowsMouse.enable = lib.mkDefault true;
        warpMouseToFocus = lib.mkDefault true;
        focusAcrossMonitors = lib.mkDefault true;

        # With hover focus the pointer is in the top-left corner often
        # enough to open the overview by accident; Mod+Tab and Mod+O stay.
        hotCorners.enable = lib.mkDefault false;

        # Glove80/TailorKey layer cheat sheet; the same key closes it.
        extraBinds = lib.mkIf config.hakkabara.apps.tailorkey.enable ''
          Mod+Shift+T hotkey-overlay-title="TailorKey-Layer" {
              spawn "tk";
          }
        '';

        # The viewer opens floating; its title carries the store path of the
        # rendered pages, so other imv windows keep the default rules.
        extraConfig = lib.mkIf config.hakkabara.apps.tailorkey.enable ''
          window-rule {
              match app-id=r#"^imv$"# title=r#"tailorkey-layers"#

              open-floating true
              open-focused true
              default-column-width { fixed 1400; }
              default-window-height { fixed 730; }
          }

          // Its search (Ctrl+F) floats on top of it.
          window-rule {
              match app-id=r#"^tailorkey-search$"#

              open-floating true
              open-focused true
              default-column-width { fixed 900; }
              default-window-height { fixed 460; }
          }
        '';
      };

      # Sidebar of the Open/Save dialog (xdg-desktop-portal). Extend the list
      # here or from another module; customer folders come with customer.
      fileChooserPins = {
        enable = lib.mkDefault true;
        pins = [
          # The parent folder, not /data/nfs/llm itself: file managers check
          # every sidebar entry when they open, and touching an automount of
          # a server that is off blocks them until the mount times out.
          {
            path = "/data/nfs";
            label = "NFS (LLM, Obsidian)";
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
