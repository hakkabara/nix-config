{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/accounts/primary.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/networking/deployment-lan.nix
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/virtualization/vmware.nix
  ];

  networking.hostName = "deploy-vm";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # mko is the dedicated DeployVM administrator and is already a wheel user.
    # Nix trusted-users are effectively root-equivalent, which is intentional
    # here so remote deployments can populate the target Nix store.
    trusted-users = [
      "mko"
    ];
  };

  # VMware UEFI supports persistent EFI variables. Prefer a normal NVRAM
  # boot entry over relying solely on the removable-media fallback path.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub.efiInstallAsRemovable = false;
  };

  # Headless administration still needs terminal descriptions for clients
  # such as Kitty. Keep efibootmgr available for EFI recovery/diagnostics.
  environment = {
    enableAllTerminfo = true;
    systemPackages = [ pkgs.efibootmgr ];
  };

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

    # Dedicated DeployVM administration identity.
    #
    # Only the public key is stored in the public Nix configuration.
    # The corresponding private key remains outside Git.
    openssh.authorizedKeys.keyFiles = [
      ./keys/deploy-vm-admin.pub
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
    # Declarative primary account password via sops-nix.
    accounts.primary = {
      enable = true;
      username = "mko";

      password = {
        sopsFile = ../../secrets/deploy-vm/users.yaml;
        secretName = "users/mko-password-hash";
        key = "mko-password-hash";
      };
    };

    # NetworkManager is intentional even though this is a headless VM:
    # the DeployVM will later use the same interactive corporate VPN tooling
    # and 2FA workflow as the WorkVM.
    networking = {
      enable = true;
      backend = "networkmanager";
      mode = "dhcp";

      deploymentLan = {
        enable = true;
        interface = "ens37";

        ipv4 = {
          address = "192.168.245.10";
          prefixLength = 24;
        };
      };
    };

    vmware = {
      enable = true;

      headless = true;
      graphics.enable = false;

      # Import/bootstrap channel only.
      #
      # VMware Workstation exposes exactly one share named:
      #
      #   deployvm
      #
      # The guest mounts it as /mnt/deploy-bootstrap and sees it read-only.
      # Keep only encrypted recovery material and explicitly prepared import
      # material here; never store the plaintext DeployVM AGE identity.
      sharedFolders = {
        enable = true;
        source = ".host:/deployvm";
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

      # This VM has been explicitly configured and verified to boot via UEFI,
      # so it does not need the extra legacy BIOS boot partition.
      boot.biosCompatibility = false;

      encryption = {
        enable = true;

        # nixos-anywhere uploads the initial LUKS passphrase here.
        # Normal nixos-rebuild does not format the disk or consume this file.
        installPasswordFile = "/tmp/disko-luks-password";

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
