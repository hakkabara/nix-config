# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

{
  imports = [
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
    ../../modules/nixos/apps/steam.nix
    ../../modules/nixos/security/sops.nix
  ];

  hakkabara = {
    workstationVm.enable = true;

    apps.steam.enable = true;

    python = {
      python3.enable = true;
      python2.enable = true;
    };

    vmware.waylandClipboard.enable = true;
  };

  home-manager.users.hakkabara = {
    imports = [
      ../../users/hakkabara
      ../../profiles/home/workstation-base.nix
      ../../modules/home/desktop/plasma
      ../../modules/home/ssh/personal-infra.nix
      ../../modules/home/desktop/autostart.nix
    ];

    # SurfVM-specific Yazi navigation.
    # /data is the VMware shared-folder mount on this VM.
    hakkabara = {
      theme.matugen.enable = true;
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

      desktop.plasma = {
        enable = true;
        alwaysOn.enable = true;
        i3Style.enable = true;
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

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };
  networking.hostName = "surf-vm"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
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
