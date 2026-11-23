# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  pkgsUnstableUnfree,
  ...
}:

{
  imports = [
    ../../modules/nixos/tools/development.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
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
    ../../modules/nixos/apps/miniserve-firewall.nix
    ../../modules/nixos/apps/kdeconnect-media
    ../../modules/nixos/apps/remote-desktop
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/accounts/primary.nix
    ../../modules/nixos/desktop/autologin.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/networking/deployment-lan.nix
    ../../modules/nixos/nix/binary-cache-client.nix
    ./obsidian-nfs.nix
    ../../modules/nixos/security/remote-unlock.nix
    ../../modules/nixos/flatpak
    ../../modules/nixos/flatpak/surf-vm.nix
  ];

  hakkabara = {
    # Remote NixOS deployments from the SurfVM.
    tools.development.nixosAnywhere.enable = true;
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
    networking = {
      enable = true;

      # "deployment" VMware network: static 192.168.245.12 from
      # deployment-lan-hosts.nix, /etc/hosts for git/cache, internal CA.
      deploymentLan = {
        enable = true;
        interface = "ens33";
        caCertificate = ../../keys/deploy-lan-ca.crt;
      };
    };

    # Harmonia cache on the DeployVM; cache.nixos.org stays the fallback.
    nix.binaryCache = {
      enable = true;
      url = "http://cache.${config.hakkabara.networking.deploymentLan.domain}:5000";
      publicKeyFile = ../../keys/harmonia-cache.pub;
    };

    apps.steam.enable = true;
    apps.remoteDesktop.rustdesk.enable = true;

    python = {
      python3.enable = true;
      python2.enable = true;
    };

    vmware = {
      enable = true;
      # TEMPORARY: compare the display topology VMware requests on Windows
      # unlock with the WorkVM. Turn off again after the capture.
      debugLogging = true;
      sharedFolders.enable = true;
      waylandClipboard.enable = true;
    };

    # Permanent SurfVM storage layout. The same configuration is used both
    # by nixos-anywhere for fresh installs and by the running system.
    storage.disko = {
      enable = true;
      filesystem = "btrfs";

      partition.systemSize = "100%";

      encryption = {
        enable = true;

        # nixos-anywhere uploads the initial LUKS password here.
        # Normal nixos-rebuild does not format the disk or consume this file.
        installPasswordFile = "/tmp/disko-luks-password";

        allowDiscards = true;
        yubikey.enable = true;
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

    # Hide what plays here from the WorkVM, keep play/pause/next there.
    programs.plasma.hotkeys.commands.media-privacy = {
      name = "Media privacy";
      key = "Meta+Alt+M";
      command = "media-privacy toggle";
      logs.enabled = false;
    };

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

      git.githubCli = {
        enable = true;
        tokenFile = config.sops.secrets."github/gh-token".path;
      };

      apps = {
        pihole.enable = true;

        # `immich` wrapper with URL + API key from sops: re-enable together
        # with the immich/* secrets once secrets/surf-vm/immich.yaml holds
        # quoted string values (sops-nix rejects non-string values).
        # immich = {
        #   urlFile = config.sops.secrets."immich/url".path;
        #   apiKeyFile = config.sops.secrets."immich/api-key".path;
        # };

        miniserve = {
          enable = true;
          profile = "surf-vm";
        };
      };

      ai = {
        enable = true;

        claude = {
          enable = true;

          code = {
            enable = true;

            # The API rejects outdated clients; stable lags behind.
            package = pkgsUnstableUnfree.claude-code;

            # Own subscription token for the SurfVM (claude setup-token),
            # read from sops at runtime; it never enters the store.
            oauthToken = {
              file = config.sops.secrets."claude/oauth-token".path;
              expiresFile = config.sops.secrets."claude/oauth-token-expires".path;
            };

            # Allowlist sandbox in chat mode, as on the WorkVM: Claude starts
            # only below ~/claude-code, sees only that project and runs nothing.
            isolation = {
              enable = true;
              projectRoots = [ "~/claude-code" ];
            };
          };
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
          firefox = {
            enable = true;
            profileName = "surf";
            profileDisplayName = "Surf";
            profileId = 0;
          };

          floorp = {
            enable = true;
            profileName = "surf";
            profileDisplayName = "Surf";
            profileId = 0;
            whatsappProfile.enable = true;
          };

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
                # Keep login/session state for selected trusted web apps.
                persistentOrigins = [
                  "https://web.whatsapp.com"

                  "https://chatgpt.com"
                  "https://auth.openai.com"

                  "https://gemini.google.com"

                  "https://claude.ai"
                ];
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

          extensions = {
            # Common workstation extensions are inherited from
            # workstation-base: uBlock Origin, Consent-O-Matic,
            # Dark Reader and the Tokyo Night theme.

            violentmonkey = {
              enable = true;
              firefox.runtimeBlockedHosts = [
                "*://*"
              ];
            };

            bitwarden.enable = true;
            multiAccountContainers.enable = true;

            sponsorBlock = {
              enable = true;
              firefox = {
                runtimeBlockedHosts = [
                  "*://*"
                ];
                runtimeAllowedHosts = [
                  "https://*.youtube.com"
                  "https://www.youtube-nocookie.com"
                  "https://sponsor.ajay.app"
                ];
              };
            };

            enhancerForYouTube = {
              enable = true;
              firefox = {
                runtimeBlockedHosts = [
                  "*://*"
                ];
                runtimeAllowedHosts = [
                  "https://www.youtube.com"
                ];
              };
            };

            twitchAdSolutions.enable = true;
          };
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

  hakkabara.apps.miniserveFirewall = {
    enable = true;
    port = 8443;
    user = "hakkabara";
  };

  # Share local media players (YouTube, Spotify) with the WorkVM, which
  # shows and controls them. Only the media plugin is installed.
  hakkabara.apps.kdeconnectMedia = {
    enable = true;
    share.enable = true;
    # Interim: deployment LAN. A dedicated KDE Connect network only needs
    # a new interface and peer addresses here and on the peers.
    network = {
      interface = "ens33";
      peers.work-vm = config.hakkabara.networking.deploymentLan.hosts.work-vm.address;
    };
  };

  hakkabara.desktop.autologin = {
    enable = true;
    user = "hakkabara";
    session = "plasma";
  };

  networking = {
    hostName = "surf-vm"; # Define your hostname.

    # Inbound stays closed. The `share` command (miniserve) opens its port
    # only while it runs, see hakkabara.apps.miniserveFirewall. NFS for the
    # Obsidian vault is opened on the deployment LAN only (obsidian-nfs.nix).

    # Fixed NetworkManager profile per interface instead of the automatic
    # "Wired connection N" profiles, which attach to whichever NIC comes up
    # first. The deployment LAN profile comes from deploymentLan (ens33).
    networkmanager = {
      enable = true;
      settings.main.no-auto-default = "*";

      ensureProfiles.profiles = {
        # VMware NAT: internet uplink and default route.
        hakkabara-uplink = {
          connection = {
            id = "hakkabara-uplink";
            type = "ethernet";
            interface-name = "ens34";
            autoconnect = true;
            autoconnect-priority = 100;
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };

        # VMnet1 (REMnux/LLM host-only); never the default route.
        hakkabara-vmnet1 = {
          connection = {
            id = "hakkabara-vmnet1";
            type = "ethernet";
            interface-name = "ens38";
            autoconnect = true;
            autoconnect-priority = 100;
          };
          ipv4 = {
            method = "auto";
            never-default = true;
            ignore-auto-dns = true;
          };
          ipv6.method = "disabled";
        };

        # VMnet4 (planned NFS network WorkVM <-> SurfVM); unused for now.
        hakkabara-vmnet4 = {
          connection = {
            id = "hakkabara-vmnet4";
            type = "ethernet";
            interface-name = "ens39";
            autoconnect = true;
            autoconnect-priority = 100;
          };
          ipv4 = {
            method = "auto";
            never-default = true;
            ignore-auto-dns = true;
          };
          ipv6.method = "disabled";
        };
      };
    };
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
    # Pinned to the existing value: the NFS export squashes to this uid.
    uid = 1000;
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
