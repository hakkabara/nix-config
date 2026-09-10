# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ../../modules/nixos/tools/development.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./secrets.nix
    ./wireguard.nix
    ../../modules/nixos/networking/personal-smb.nix
    ../../modules/nixos/virtualization/vmware.nix
    ../../modules/nixos/virtualization/vmware-wayland-clipboard.nix
    ../../modules/nixos/features/workstation-vm.nix
    ../../modules/nixos/features/python.nix
    ../../modules/nixos/audio/pipewire.nix
    ../../modules/nixos/desktop/plasma.nix
    ../../modules/nixos/apps/flameshot-plasma.nix
    ../../modules/nixos/input/eurkey.nix
    ../../modules/nixos/apps/steam.nix
    ../../modules/nixos/apps/remote-desktop
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/accounts/primary.nix
    ../../modules/nixos/desktop/autologin.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/boot/loader.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/security/remote-unlock.nix
    ../../modules/nixos/flatpak
    ../../modules/nixos/flatpak/surf-vm.nix
  ];

  hakkabara = {
    # VMware host keeps GRUB for BIOS/UEFI compatibility.
    boot.loader = {
      enable = true;
      backend = "grub";
    };

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
    networking.enable = true;

    apps.steam.enable = true;
    apps.remoteDesktop.rustdesk.enable = true;

    python = {
      python3.enable = true;
      python2.enable = true;
    };

    vmware = {
      enable = true;
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
      ../../profiles/home/personal-workstation.nix
      ../../modules/home/desktop/plasma
      ../../modules/home/desktop/monitor
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
      git.githubCli = {
        enable = true;
        tokenFile = config.sops.secrets."github/gh-token".path;
      };

      helpers.pihole.enable = true;

      apps = {

        miniserve.profile = "surf-vm";
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
