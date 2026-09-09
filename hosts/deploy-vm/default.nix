{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/virtualization/vmware.nix
  ];

  networking.hostName = "deploy-vm";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Berlin";

  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
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
  };

  programs.zsh.enable = true;

  users.users.mko = {
    isNormalUser = true;
    description = "mko";
    shell = pkgs.zsh;

    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # SSH is part of the appliance baseline, but password authentication remains
  # disabled. The actual administration key is added during the next bootstrap
  # step before we install the VM.
  services.openssh = {
    enable = true;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  hakkabara = {
    # NetworkManager is intentional even though this is a headless VM:
    # the DeployVM will later use the same interactive corporate VPN tooling
    # and 2FA workflow as the WorkVM.
    networking = {
      enable = true;
      backend = "networkmanager";
      mode = "dhcp";
    };

    vmware = {
      enable = true;

      headless = true;
      graphics.enable = false;

      # Import/bootstrap channel only.
      #
      # In VMware Workstation we will create exactly one share named:
      #
      #   deploy-bootstrap
      #
      # It will initially contain the DeployVM AGE identity and corporate VPN
      # import material. The guest sees it read-only.
      sharedFolders = {
        enable = true;
        source = ".host:/deploy-bootstrap";
        mountPoint = "/mnt/deploy-bootstrap";
        readOnly = true;
        automount.enable = true;

        uid = 1000;
        gid = 100;
        umask = "0077";
      };
    };

    # Sensitive deployment/cache appliance:
    #
    #   /dev/sda
    #     -> GPT
    #     -> LUKS2
    #     -> Btrfs
    #        /root
    #        /nix
    #        /persist
    #        /swap
    #
    # /nix gets its own Btrfs subvolume, which is useful for the future
    # Harmonia-backed cache/store.
    storage.disko = {
      enable = true;
      device = "/dev/sda";
      filesystem = "btrfs";

      partition.systemSize = "100%";

      encryption = {
        enable = true;

        # Do not leak free-block information through LUKS by default.
        # We can deliberately revisit this if thin-disk reclaim becomes
        # important enough to justify the trade-off.
        allowDiscards = false;
      };

      btrfs = {
        compression = "zstd";
        noatime = true;
        prepareForImpermanence = true;
      };

      swap = {
        enable = true;
        sizeMiB = 8192;
      };

      trim.enable = true;
    };
  };

  home-manager.users.mko = {
    imports = [
      ../../users/mko
      ../../profiles/home/deploy-vm.nix
    ];
  };

  # Do not change during normal updates.
  system.stateVersion = "26.05";
}
