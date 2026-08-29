{
  pkgs,
  pkgsUnstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # Shared workstation/VM integration.
    ../../modules/nixos/features/workstation-vm.nix
    ../../modules/nixos/features/python.nix
    ../../profiles/nixos/work-vm-tools.nix
    ../../modules/nixos/virtualization/vmware.nix
    ../../modules/nixos/virtualization/vmware-wayland-clipboard.nix

    # Desktop foundation.
    ../../modules/nixos/audio/pipewire.nix
    ../../modules/nixos/input/eurkey.nix
    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/dms.nix
    ../../modules/nixos/desktop/autologin.nix

    # Shared system policies.
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/security/sops.nix
    ../../modules/nixos/accounts/primary.nix
  ];

  networking.hostName = "work-vm";

  # Keep the normal NixOS system/package set on 26.05 stable.
  # Only explicitly selected fast-moving packages come from pkgsUnstable.
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

  users.users.mko = {
    isNormalUser = true;
    description = "mko";
    shell = pkgs.zsh;

    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  hakkabara = {
    # Declarative primary account password via sops-nix.
    accounts.primary = {
      enable = true;
      username = "mko";

      password = {
        sopsFile = ../../secrets/work-vm/users.yaml;
        secretName = "users/mko-password-hash";
        key = "mko-password-hash";
      };
    };

    # Workstation VM policy: never suspend/hibernate independently.
    workstationVm.enable = true;

    # Python runtimes used by WorkVM tooling.
    # Python 2 is intentionally limited to this legacy/security-tool use case.
    python = {
      python3.enable = true;
      python2.enable = true;
    };

    # DHCP through NetworkManager.
    networking.enable = true;

    # VMware host <-> Wayland clipboard bridge.
    vmware.waylandClipboard.enable = true;

    # Permanent WorkVM storage layout.
    #
    # WorkVM intentionally does not use full-disk encryption:
    #   /dev/sda
    #   GPT + EFI/BIOS compatibility
    #   Btrfs + zstd
    #   Btrfs swapfile
    #   prepared /persist subvolume
    storage.disko = {
      enable = true;
      device = "/dev/sda";
      filesystem = "btrfs";

      partition.systemSize = "100%";

      encryption.enable = false;

      btrfs.prepareForImpermanence = true;

      swap = {
        enable = true;
        sizeMiB = 8192;
      };

      trim.enable = true;
    };

    # Native NixOS Niri integration, but use the explicitly pinned
    # nixos-unstable packages for the fast-moving compositor stack.
    desktop.niri = {
      enable = true;

      package = pkgsUnstable.niri;

      xwayland = {
        enable = true;
        package = pkgsUnstable.xwayland-satellite;
      };
    };

    # Automatic login directly into the Niri session.
    desktop.autologin = {
      enable = true;
      user = "mko";
      session = "niri";
    };
  };

  # DankGreeter is the official Dank desktop greeter.
  #
  # NixOS 26.05 already provides the native integration, so there is no
  # reason to add another greeter flake or custom greetd configuration.
  # DankMaterialShell uses the native NixOS 26.05 module while the
  # fast-moving runtime packages come explicitly from nixpkgs-unstable.
  #
  # DankGreeter automatically inherits these same packages.
  hakkabara.desktop.dms = {
    enable = true;
    package = pkgsUnstable.dms-shell;
    quickshellPackage = pkgsUnstable.quickshell;
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
  };

  home-manager.users.mko = {
    imports = [
      ../../users/mko
      ../../profiles/home/work-vm.nix
    ];
  };

  # Do not change this on normal updates.
  system.stateVersion = "26.05";
}
