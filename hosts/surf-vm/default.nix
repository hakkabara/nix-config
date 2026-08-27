# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./storage-legacy.nix
    ./secrets.nix
    ./wireguard.nix
    ./mounts.nix
    ../../modules/nixos/virtualization/vmware.nix
    ../../modules/nixos/virtualization/vmware-wayland-clipboard.nix
    ../../modules/nixos/features/workstation-vm.nix
    ../../modules/nixos/features/python.nix
    ../../modules/nixos/audio/pipewire.nix
    ../../modules/nixos/desktop/plasma.nix
    ../../modules/nixos/apps/flameshot-plasma.nix
    ../../modules/nixos/input/eurkey.nix
    ../../modules/nixos/apps/steam.nix
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/accounts/primary.nix
    ../../modules/nixos/desktop/autologin.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/security/remote-unlock.nix
    ../../modules/nixos/flatpak
  ];

  hakkabara = {
    workstationVm.enable = true;

    accounts.primary = {
      enable = true;
      username = "hakkabara";

      password = {
        sopsFile = ../../secrets/surf-vm/users.yaml;
        secretName = "users/hakkabara-password-hash";
        key = "hakkabara-password-hash";
      };
    };

    # DHCP is the default. Hosts can override this with a static profile.
    networking.enable = true;

    apps.steam.enable = true;

    python = {
      python3.enable = true;
      python2.enable = true;
    };

    vmware.waylandClipboard.enable = true;

    # Keep the live SurfVM on its current ext4 layout. Flip this to true only
    # for a fresh Disko reinstall; never switch it on via nixos-rebuild on the
    # existing ext4 installation.
    storage.disko = {
      enable = false;
      filesystem = "btrfs";

      partition.systemSize = "100%";

      encryption = {
        enable = true;
        allowDiscards = true;
        yubikey.enable = false;
      };

      btrfs.prepareForImpermanence = true;

      swap = {
        enable = true;
        sizeMiB = 8192;
      };

      trim.enable = true;
    };
  };

  home-manager.users.hakkabara = {
    imports = [
      ../../users/hakkabara
      ../../profiles/home/workstation-base.nix
      ../../profiles/home/surf-vm-apps.nix
      ../../modules/home/desktop/plasma
      ../../modules/home/desktop/monitor
      ../../modules/home/ssh/personal-infra.nix
      ../../modules/home/desktop/autostart.nix
      ../../modules/home/apps/flameshot/plasma.nix
    ];

    # KWallet is intentionally disabled on the SurfVM.
    # With graphical autologin there is no login password available
    # to unlock a password-protected wallet automatically.
    programs.plasma.configFile.kwalletrc.Wallet = {
      Enabled = false;
      "First Use" = false;
    };

    # SurfVM-specific Yazi navigation.
    # /data is the VMware shared-folder mount on this VM.
    hakkabara = {
      theme.matugen.enable = true;

      apps = {
        pihole.enable = true;

        miniserve = {
          enable = true;
          profile = "surf-vm";
        };
      };

      ai = {
        enable = true;

        claude = {
          enable = true;
          code.enable = true;
          omc.enable = true;
        };
      };

      cli.yazi.extraKeymap = [
        {
          on = [
            "g"
            "s"
          ];
          run = "cd /data";
          desc = "Go to shared data";
        }
      ];

      # SurfVM browser selection.
      #
      # Extension defaults come from workstation-base.nix and can be
      # selectively overridden here.
      browsers = {
        gecko = {
          firefox.enable = true;
          floorp.enable = true;

          # SurfVM Firefox selective Sync.
          #
          # Only dynamic browsing state is synchronized. Declarative
          # data such as bookmarks, extensions and browser settings
          # remains managed locally through Nix/Home Manager.
          sync.firefox = {
            enable = true;
            locked = true;

            history = true;
            openTabs = true;

            bookmarks = false;
            passwords = false;
            addons = false;
            settings = false;
            addresses = false;
            paymentMethods = false;
          };

          # SurfVM-specific Gecko privacy configuration.
          #
          # Shared values apply to Firefox and Floorp. Individual
          # browsers/profiles may inherit, extend, replace, or
          # completely discard the common cookie persistence list.
          privacy = {
            antiClutter.enable = true;

            # Disable live remote search-engine suggestions while
            # retaining local history/bookmark/open-tab results.
            remoteSearchSuggestions.enable = false;

            cookies = {
              common = {
                # Cookies and site storage work during the session
                # but are removed after the browser fully exits.
                clearOnShutdown = true;

                # Shared SurfVM persistence whitelist.
                persistentOrigins = [ ];
              };

              # Both currently inherit the SurfVM common baseline.
              firefox.mode = "inherit";
              floorp.mode = "inherit";

              # Future examples:
              #
              # firefox = {
              #   mode = "extend";
              #   persistentOrigins = [
              #     "https://firefox-only.example"
              #   ];
              # };
              #
              # floorp = {
              #   mode = "replace";
              #   persistentOrigins = [
              #     "https://floorp-only.example"
              #   ];
              # };
              #
              # profiles.firefox.work = {
              #   mode = "extend";
              #   persistentOrigins = [
              #     "https://profile-only.example"
              #   ];
              # };
              #
              # profiles.floorp.throwaway = {
              #   mode = "none";
              #   clearOnShutdown = true;
              # };
            };
          };

          bookmarks.manager = {
            enable = true;

            # Existing encrypted filename retained during this migration.
            # The manager implementation itself is browser-neutral.
            sourceFile = "secrets/surf-vm/browser-bookmarks";
            documentTitle = "SurfVM Bookmarks";
          };

          extensions.tokyoNightTheme.enable = true;
          extensions.twitchAdSolutions.enable = true;
        };

        chromium = {
          chromium.enable = true;
          vivaldi.enable = true;
        };
      };

      desktop.monitor = {
        enable = true;
        backend = "plasma";
        safeOutput = "Virtual-1";

        watcher = {
          enable = true;
          # Event-driven on Plasma/Niri. These values are only short settling
          # and safety fallback windows; there is no tight polling loop.
          debounceSeconds = 1;
          fallbackPollSeconds = 30;
          promptTimeoutSeconds = 10;
          popupDelayMilliseconds = 250;
        };

        profiles = {
          homeoffice = {
            # Calibrated against the real Home Office VMware/KScreen layout:
            # 1920x1080 Virtual-2 on the left, 2560x1440 Virtual-1 on the right.
            leftOutput = "Virtual-2";
            rightOutput = "Virtual-1";
            primaryOutput = "Virtual-1";
            verticalAlignment = "top";
          };

          office = {
            leftOutput = "Virtual-1";
            rightOutput = "Virtual-2";
            primaryOutput = "Virtual-1";
            verticalAlignment = "top";
          };
        };
      };

      desktop.plasma = {
        enable = true;
        alwaysOn.enable = true;
        i3Style.enable = true;
        windowLayout.enable = true;
        rice.enable = true;
        emptySession.enable = true;
        xwaylandInputNoPrompt.enable = true;
        panel = {
          enable = true;

          launchers = [
            "applications:floorp.desktop"
            "applications:org.kde.dolphin.desktop"
            "applications:kitty.desktop"
          ];
        };
      };
    };

  };
  # Steam runs inside a Bubblewrap FHS environment.
  # /data is a VMware vmhgfs-fuse mount and cannot be bind-mounted into it.
  # Remove this override when the SurfVM no longer uses the VMware shared folder.
  programs.steam.package = pkgs.steam.override {
    extraPreBwrapCmds = ''
      ignored+=(/data)
    '';
  };

  # Enable the modern Nix CLI and Flakes.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  hakkabara.desktop.autologin = {
    enable = true;
    user = "hakkabara";
    session = "plasma";
  };

  networking = {
    hostName = "surf-vm"; # Define your hostname.

    # Enable networking
    networkmanager.enable = true;

    firewall.allowedTCPPorts = [
      8443
    ];
  };

  # Mount shared folder
  fileSystems."/data" = {
    device = ".host:/data";
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    options = [
      "rw"
      "allow_other"
      "nofail"
      "x-systemd.automount"
    ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  programs.zsh.enable = true;

  environment.pathsToLink = [
    "/share/zsh"
  ];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."hakkabara" = {
    isNormalUser = true;
    description = "hakkabara";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    htop
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
