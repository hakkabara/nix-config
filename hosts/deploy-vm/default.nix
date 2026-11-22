{
  config,
  lib,
  pkgs,
  pkgsDfir,
  pkgsUnstableUnfree,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/nixos/accounts/primary.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/networking/deployment-lan.nix
    ../../modules/nixos/nix/cache-retention.nix
    ../../modules/nixos/services/forgejo.nix
    ../../modules/nixos/services/harmonia-cache.nix
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/virtualization/vmware.nix
    ../../modules/nixos/tools/deployment/default.nix
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
    # SSH only from the deployment LAN, like Forgejo and the cache. The
    # VMware NAT uplink must not expose any service.
    openFirewall = false;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.interfaces.ens37.allowedTCPPorts = [ 22 ];

  hakkabara.tools.deployment = {
    enable = true;

    # Managed checkouts come from the local Forgejo over SSH with a key that
    # never leaves this machine. Repository URLs and the build flake are set
    # from nix-internal; the public default stays GitHub nix-config.
    sshKey = {
      enable = true;
      knownHostNames = [ config.hakkabara.services.forgejo.domain ];
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

    # Keep known-good client closures in the DeployVM Nix store.
    # The actual current/previous targets remain runtime state and are not
    # hard-coded into the repository.
    nix.cacheRetention.enable = true;

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
        caCertificate = ../../keys/deploy-lan-ca.crt;
      };
    };

    services.harmoniaCache = {
      enable = true;

      bindAddress = config.hakkabara.networking.deploymentLan.ipv4.address;
      port = 5000;
      interface = "ens37";

      signingKey = {
        sopsFile = ../../secrets/deploy-vm/harmonia.yaml;
        secretName = "harmonia-cache-signing-key";
        key = "cache-signing-key";
      };
    };

    # Internal Git server for repositories and secrets that must never leave
    # the deployment LAN, plus pull mirrors for offline deployments.
    services.forgejo = {
      enable = true;

      bindAddress = config.hakkabara.networking.deploymentLan.ipv4.address;
      domain = "git.${config.hakkabara.networking.deploymentLan.domain}";
      port = 3000;
      interface = "ens37";

      # Certificate and key are set from nix-internal:
      #   hakkabara.services.forgejo.tls = { enable = true; sopsFile = ...; };

      admin.password.sopsFile = ../../secrets/deploy-vm/forgejo.yaml;

      # Names, upstream URLs and credentials stay encrypted.
      repositories = {
        enable = true;
        sopsFile = ../../secrets/deploy-vm/forgejo-repositories.yaml;

        # Read-only access for deploy-repo-sync / deploy-build; attached to
        # the repositories marked "deployKey: true" in the document.
        deployKey.publicKeyFile = "/persist/deployment/ssh/id_ed25519.pub";
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

    hakkabara.ai = {
      enable = true;

      claude = {
        enable = true;

        code = {
          enable = true;

          # The API rejects outdated clients; stable lags behind.
          package = pkgsUnstableUnfree.claude-code;

          # Allowlist sandbox in chat mode: Claude starts only below
          # ~/claude-code, sees only that project and runs nothing.
          isolation = {
            enable = true;
            projectRoots = [ "~/claude-code" ];
          };
        };
      };
    };
  };

  # The appliance allows no unfree packages except the Claude Code launcher,
  # which inherits the license of the package it wraps.
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code-launcher";

  # Do not change during normal updates.
  system.stateVersion = "26.05";

  # Mirror for upstream downloads without a versioned URL: their pinned
  # fixed-output store paths stay in this store (part of the system
  # closure) and Harmonia serves them to every cache client, so builds keep
  # working when upstream silently replaces a file. Store paths are keyed
  # by hash, so the mirror can never serve different content.
  # Eric Zimmerman tools: https://download.mikestammer.com/net9/<tool>.zip
  system.extraDependencies = pkgsDfir.ez-tools.srcs;
}
