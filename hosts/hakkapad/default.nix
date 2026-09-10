{
  config,
  dms,
  pkgs,
  pkgsUnstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix
    ./wifi.nix

    ../../modules/nixos/tools/development.nix
    ../../modules/nixos/features/python.nix

    ../../modules/nixos/audio/pipewire.nix
    ../../modules/nixos/input/eurkey.nix

    ../../modules/nixos/apps/steam.nix
    ../../modules/nixos/apps/remote-desktop

    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/dms.nix
    ../../modules/nixos/desktop/autologin.nix

    ../../modules/nixos/networking/profile.nix

    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/boot/loader.nix
    ../../modules/nixos/storage/disko.nix

    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/accounts/primary.nix

    ../../modules/nixos/flatpak
  ];

  networking.hostName = "hakkapad";

  nixpkgs.config.allowUnfree = true;

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

  environment.pathsToLink = [
    "/share/zsh"
  ];

  users.users.hakkabara = {
    isNormalUser = true;
    description = "hakkabara";
    shell = pkgs.zsh;

    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
    ];
  };

  hakkabara = {
    # Modern UEFI-only boot path for the physical ThinkPad.
    boot.loader = {
      enable = true;
      backend = "systemd-boot";

      efi.canTouchEfiVariables = true;

      # Do not allow interactive kernel command-line editing at boot.
      systemdBoot.editor = false;
    };

    tools.development.nixosAnywhere.enable = true;

    accounts.primary = {
      enable = true;
      username = "hakkabara";

      password = {
        sopsFile = ../../secrets/hakkapad/users.yaml;
        secretName = "users/hakkabara-password-hash";
        key = "hakkabara-password-hash";
      };
    };

    networking.enable = true;

    python.python3.enable = true;

    apps.steam.enable = true;
    apps.remoteDesktop.rustdesk.enable = true;

    storage.disko = {
      enable = true;

      # Deliberately invalid until we identify the laptop SSD.
      # This prevents an accidental destructive install.
      device = "/dev/disk/by-id/REPLACE-BEFORE-DEPLOY";

      filesystem = "btrfs";

      # Physical ThinkPad is UEFI-only for our configuration.
      boot.biosCompatibility = false;

      partition.systemSize = "100%";

      encryption = {
        enable = true;
        installPasswordFile = "/tmp/disko-luks-password";

        # We can revisit this during laptop tuning.
        allowDiscards = true;

        # Enroll YubiKey/FIDO2 only after password boot is proven.
        yubikey.enable = false;
      };

      btrfs.prepareForImpermanence = true;

      swap = {
        enable = true;
        sizeMiB = 8192;
      };

      trim.enable = true;
    };

    desktop = {
      niri = {
        enable = true;
        package = pkgsUnstable.niri;

        xwayland = {
          enable = true;
          package = pkgsUnstable.xwayland-satellite;
        };
      };

      autologin = {
        enable = true;
        user = "hakkabara";
        session = "niri";
      };

      dms = {
        enable = true;
        package = dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
        quickshellPackage = pkgsUnstable.quickshell;
      };
    };
  };

  services = {
    displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
    };

    printing.enable = true;
    fwupd.enable = true;
    upower.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
  };

  # Generic physical-laptop functionality.
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    graphics.enable = true;
  };

  home-manager.users.hakkabara = {
    imports = [
      ../../users/hakkabara
      ../../profiles/home/hakkapad.nix
    ];

    hakkabara.git.githubCli = {
      enable = true;
      tokenFile = config.sops.secrets."github/gh-token".path;
    };

    hakkabara.desktop.dms = {
      controlCenter = {
        enable = true;

        icons = {
          network = true;
          bluetooth = true;
          audio = true;
          vpn = true;
          brightness = true;
          mic = true;
          battery = true;
          screenSharing = true;
        };

        widgets = {
          volumeSlider = true;
          brightnessSlider = true;
          wifi = true;
          bluetooth = true;
          audioOutput = true;
          audioInput = true;
          nightMode = true;
          darkMode = false;
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    pciutils
    usbutils
    nvme-cli
  ];

  system.stateVersion = "26.05";
}
