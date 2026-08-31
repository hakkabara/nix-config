{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    # Shared workstation/VM integration.
    ../../modules/nixos/features/workstation-vm.nix
    ../../modules/nixos/features/python.nix
    ../../modules/nixos/features/wireshark.nix
    ../../modules/nixos/apps/remote-desktop
    ../../modules/nixos/apps/teams.nix
    ../../modules/nixos/flatpak
    ../../profiles/nixos/work-vm-tools.nix
    ../../modules/nixos/virtualization/vmware.nix
    ../../modules/nixos/virtualization/vmware-wayland-clipboard.nix
    ../../modules/nixos/virtualization/docker.nix

    # Desktop foundation.
    ../../modules/nixos/audio/pipewire.nix
    ../../modules/nixos/input/eurkey.nix
    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/dms.nix
    ../../modules/nixos/desktop/autologin.nix

    # Shared system policies.
    ../../modules/nixos/network/vpn-clients.nix
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

  # WorkVM intentionally runs without a desktop keyring/Secret Service.
  # KeePassXC is only used to open local KDBX vaults and does not replace it.
  # Autologin would otherwise cause interactive keyring creation/unlock prompts.
  services.gnome.gnome-keyring.enable = lib.mkForce false;

  security.pam.services.login.enableGnomeKeyring = lib.mkForce false;
  security.pam.services.greetd.enableGnomeKeyring = lib.mkForce false;

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

    # Teams inside the VM is intentionally limited to chat/downloads.
    # Calls and meetings are handled on the Windows host.
    apps.teams = {
      enable = true;
      user = "mko";
      chatOnly = true;
    };

    # Remote support clients. All are started manually when needed;
    # no permanent RMM daemon is enabled.
    apps.remoteDesktop = {
      rustdesk.enable = true;
      anydesk.enable = true;
      teamviewer.enable = true;
    };

    # Wireshark GUI with privileged dumpcap wrapper for non-root captures.
    wireshark = {
      enable = true;
      users = [ "mko" ];
      usbCapture = false;
    };

    # Rootful Docker for containerized DFIR/security tooling.
    # Members of the docker group effectively have root-equivalent access.
    virtualization.docker = {
      enable = true;
      users = [ "mko" ];

      preloadImages = [
        "docker.io/specterops/bloodhound:9.5.1"
        "docker.io/library/postgres:18"
        "docker.io/library/neo4j:4.4.42"
        "docker.io/library/neo4j:4.4.20"
        "docker.io/scmanjarrez/bloodhound:4.3.1"
        "docker.io/log2timeline/plaso:20260720"
        "ghcr.io/velocidex/velociraptor-server:0.77.2"

        # Network forensics / timeline analysis.
        "docker.io/zeek/zeek:8.2.1"

        # Timesketch release stack.
        "us-docker.pkg.dev/osdfir-registry/timesketch/timesketch:20260630"
        "docker.io/opensearchproject/opensearch:2.19.5"
        "docker.io/library/postgres:13.0-alpine"
        "docker.io/library/redis:7.2.11-alpine"
        "docker.io/library/nginx:1.25.5-alpine-slim"

        # Arkime packet analysis.
        "ghcr.io/arkime/arkime/arkime:v6.6.0"
      ];
    };

    # DHCP through NetworkManager.
    networking.enable = true;

    # Generic VPN client capabilities only.
    # No SurfVM Homelab VPN profiles are imported into the WorkVM.
    network.vpnClients = {
      enable = true;

      openvpn = {
        enable = true;
        networkManager.enable = true;
      };

      wireguard.enable = true;

      fortinet = {
        enable = true;
        networkManager.enable = true;
      };
    };

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

    hakkabara.git.githubCli = {
      enable = true;
      tokenFile = config.sops.secrets."github/gh-token".path;
    };

    programs.ssh.settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = config.sops.secrets."github/ssh-key".path;
      IdentitiesOnly = true;
    };
  };

  # Do not change this on normal updates.
  system.stateVersion = "26.05";
  boot.kernel.sysctl."vm.max_map_count" = 262144;

}
