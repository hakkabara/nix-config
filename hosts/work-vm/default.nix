{
  config,
  dms,
  lib,
  pkgs,
  pkgsUnstable,
  pkgsUnstableUnfree,
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
    ../../modules/nixos/apps/thunar.nix
    ../../modules/nixos/apps/kdeconnect-media
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
    ../../modules/nixos/services/hacktricks.nix
    # Enabled with the bookmark secret in nix-internal.
    ../../modules/nixos/desktop/managed-bookmarks.nix
    # Enabled with the CA secret in nix-internal.
    ../../modules/nixos/desktop/internal-ca.nix
    ../../modules/nixos/desktop/managed-site-search.nix

    # Shared system policies.
    ../../modules/nixos/network/vpn-clients.nix
    ../../modules/nixos/networking/profile.nix
    ../../modules/nixos/networking/deployment-lan.nix
    ../../modules/nixos/networking/split-dns.nix
    ../../modules/nixos/nix/binary-cache-client.nix
    ../../modules/nixos/maintenance.nix
    ../../modules/nixos/storage/disko.nix
    ../../modules/nixos/security/sops.nix
    # Enabled with the key document in nix-internal.
    ../../modules/nixos/security/api-keys.nix
    ../../modules/nixos/accounts/primary.nix
  ];

  networking = {
    hostName = "work-vm";

    # Name for the REMnux/LLM VM on the host-only lab network (static there
    # via netplan), e.g. http://llm.lab.internal:3080 for the DSH web UI.
    # The NFS mount further down keeps the plain address.
    hosts."192.168.36.5" = [
      "llm.lab.internal"
      "llm"
    ];
  };

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
    # HackTricks (German) offline at http://localhost:3337, launcher "HackTricks".
    services.hacktricks.enable = true;

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

    # Chrome and Chromium get the Firefox/Floorp search shortcuts (@vt, @sh, ...).
    browsers.managedSiteSearch.enable = true;

    # Workstation VM policy: never suspend/hibernate independently.
    workstationVm.enable = true;

    vmware = {
      enable = true;
      sharedFolders = {
        enable = true;
        mountPoint = "/data/share";
      };
    };

    # Python runtimes used by WorkVM tooling.
    # Python 2 is intentionally limited to this legacy/security-tool use case.
    python = {
      python3.enable = true;
      python2.enable = true;
    };

    apps = {
      # Show and control the SurfVM's media players (YouTube, Spotify) in
      # the shell's media widget. Only the media plugin is installed.
      kdeconnectMedia = {
        enable = true;
        control.enable = true;
        # Interim: deployment LAN. A dedicated KDE Connect network only
        # needs a new interface and peer addresses here and on the peers.
        network = {
          interface = "ens37";
          peers.surf-vm = config.hakkabara.networking.deploymentLan.hosts.surf-vm.address;
        };
      };

      # Teams inside the VM is intentionally limited to chat/downloads.
      # Calls and meetings are handled on the Windows host.
      teams = {
        enable = true;
        user = "mko";
        chatOnly = true;

        # Drag and drop from Thunar. Deliberate user decision (2026-11-22):
        # full read/write on home and /data, accepting that a compromised
        # Teams client could read ~/.ssh, tokens and all customer data.
        filesystemAccess = [
          "home"
          "/data"
        ];
      };

      # Graphical file manager next to Yazi (Mod+Ctrl+E): no thumbnails, no
      # automount, scripts open instead of running, SFTP via gvfs, archives
      # via xarchiver (modules/nixos/apps/thunar.nix).
      thunar = {
        enable = true;
        user = "mko";
      };

      # Remote support clients. All are started manually when needed;
      # no permanent RMM daemon is enabled.
      remoteDesktop = {
        rustdesk.enable = true;
        anydesk.enable = true;
        teamviewer.enable = true;
      };
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
        "docker.io/specterops/bloodhound:9.10.1"
        "docker.io/library/postgres:18"
        "docker.io/library/neo4j:4.4.42"
        "docker.io/library/neo4j:4.4.20"
        "docker.io/scmanjarrez/bloodhound:4.3.1"
        "docker.io/log2timeline/plaso:20261027"
        "ghcr.io/velocidex/velociraptor-server:0.77.3"

        # Network forensics / timeline analysis.
        "docker.io/zeek/zeek:9.0.1"

        # Timesketch release stack.
        "us-docker.pkg.dev/osdfir-registry/timesketch/timesketch:20260630"
        "docker.io/opensearchproject/opensearch:2.19.5"
        "docker.io/library/postgres:13.0-alpine"
        "docker.io/library/redis:7.2.11-alpine"
        "docker.io/library/nginx:1.25.5-alpine-slim"

        # Arkime packet analysis.
        "ghcr.io/arkime/arkime/arkime:v6.9.2"
      ];
    };

    # DHCP through NetworkManager.
    networking = {
      enable = true;

      deploymentLan = {
        enable = true;
        interface = "ens37";
        caCertificate = ../../keys/deploy-lan-ca.crt;
      };
    };

    nix.binaryCache = {
      enable = true;
      url = "http://cache.${config.hakkabara.networking.deploymentLan.domain}:5000";
      publicKeyFile = ../../keys/harmonia-cache.pub;
    };

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
        networkManager.enable = false;
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
    package = dms.packages.${pkgs.stdenv.hostPlatform.system}.dms-shell;
    quickshellPackage = pkgsUnstable.quickshell;
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
  };

  home-manager.users.mko = _: {
    imports = [
      ../../users/mko
      # Same uBlock Origin lists and rules (managed storage) and the same
      # Dark Reader import file as on the other workstations.
      # TwitchAdSolutions stays off here; the file only carries its settings.
      ../../users/hakkabara/browser-extensions.nix
      ../../profiles/home/work-vm.nix
      ../../modules/home/desktop/monitor
    ];

    hakkabara = {
      ai = {
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

      desktop = {
        monitor = {
          enable = true;
          backend = "niri";
          # Follow VMware's monitor arrangement.
          followHostLayout = true;
          safeOutput = "Virtual-1";

          watcher.enable = true;

          # Same VMware host monitors as the SurfVM, so the calibration is shared.
          # Niri has no primary output; primaryOutput is ignored by that backend.
          profiles = {
            homeoffice = {
              # The 1920x1080 monitor is physically left. Matching by size
              # keeps the layout right wherever the VM window was started.
              leftSize = {
                width = 1920;
                height = 1080;
              };
              leftOutput = "Virtual-2";
              rightOutput = "Virtual-1";
              verticalAlignment = "top";
            };

            office = {
              leftOutput = "Virtual-1";
              rightOutput = "Virtual-2";
              verticalAlignment = "top";
            };
          };
        };

        # Hide what plays on the SurfVM, keep play/pause/next.
        # Mod+Ctrl+M is taken by the VMware console; Super+Alt passes through.
        niri.extraBinds = ''
          Mod+Alt+M hotkey-overlay-title="Media privacy" {
              spawn "media-privacy" "toggle";
          }
        '';

        # The hotplug selector is a small Kitty window; without this rule Niri
        # would tile it as a full-height column.
        niri.extraConfig = ''
          window-rule {
              match app-id=r#"^hakkabara-monitor-selector$"#

              open-floating true
              open-focused true
              default-column-width { fixed 680; }
              default-window-height { fixed 520; }
          }
        '';

        dms = {
          alwaysOn.enable = true;

          # Colors follow the wallpaper (Matugen): shell, Kitty, GTK and, via
          # the work-vm profile, the niri borders.
          theme = "dynamic";

          # Wallpaper picker and cycling start in the repo's wallpapers.
          wallpapers.enable = true;

          # VPN status and connect menu in the bar.
          bar.vpnWidget.enable = true;

          # Music widget only on the 1440p main monitor; the second monitor
          # gets a mirrored bar without it.
          bar.mainOutputOnly.enable = true;

          controlCenter = {
            enable = true;

            icons = {
              network = true;
              bluetooth = false;
              audio = true;
              vpn = true;
              brightness = false;
              mic = false;
              battery = false;
              screenSharing = true;
            };

            widgets = {
              volumeSlider = true;
              brightnessSlider = false;
              wifi = false;
              bluetooth = false;
              audioOutput = true;
              audioInput = false;
              nightMode = true;
              darkMode = false;
            };
          };
        };
      };

      git.githubCli = {
        enable = true;
        tokenFile = config.sops.secrets."github/gh-token".path;
      };
    };

    # Internal SSH hosts and the customer template come from nix-internal
    # (modules/ssh-config there).

    programs.ssh.settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = config.sops.secrets."github/ssh-key".path;
      IdentitiesOnly = true;
    };
  };

  # Fixed NetworkManager profiles per interface. The automatic
  # "Wired connection N" profiles attach to whichever interface comes up
  # first, which can leave the uplink without any profile after a reboot
  # (no default route, VPNs fail with "Could not find source connection").
  networking.networkmanager = {
    settings.main.no-auto-default = "*";

    ensureProfiles.profiles = {
      # VMware NAT: internet uplink and default route.
      hakkabara-uplink = {
        connection = {
          id = "hakkabara-uplink";
          type = "ethernet";
          interface-name = "ens33";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
        # The emulated e1000 NIC can wedge its TX queue with segmentation
        # offload on ("e1000 ... Detected Tx Unit Hang": link up, RX works,
        # nothing is sent). Segment in software instead.
        ethtool = {
          feature-tso = false;
          feature-gso = false;
          feature-gro = false;
        };
      };

      # VMware host-only lab network to the REMnux VM; never the default route.
      hakkabara-lab-hostonly = {
        connection = {
          id = "hakkabara-lab-hostonly";
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
    };
  };

  # DSH LLM workspace share exported by the REMnux analysis VM over the
  # VMware host-only lab network (192.168.36.0/24, NFSv4.2).
  #
  # Mounted lazily on first access so the WorkVM boots normally while the
  # REMnux VM is powered off, then kept mounted (no idle unmount), and
  # "soft" so a vanished server returns an I/O error instead of hanging
  # processes forever. The share is a drop zone for
  # samples to analyse: nothing on it may execute or gain privileges here.
  fileSystems."/data/nfs/llm" = {
    device = "192.168.36.5:/opt/dsh/workspace";
    fsType = "nfs";

    options = [
      "nfsvers=4.2"
      "nosuid"
      "nodev"
      "noexec"
      "soft"
      "_netdev"
      "nofail"
      "noauto"
      "x-systemd.automount"
      # Short: an unreachable server should cost seconds, not block every
      # program that looks at the folder.
      "x-systemd.mount-timeout=5"
    ];
  };

  # Obsidian vault exported by the SurfVM over the deployment LAN
  # (NFSv4.2, only to this host's static 192.168.245.11). Open the vault in
  # Obsidian from /data/nfs/obsidian. Nothing is copied to the WorkVM: when
  # the SurfVM is off, the vault is simply not there.
  #
  # Lazy automount so the WorkVM boots while the SurfVM is off. "soft" with
  # 15 s x 3 retries rides out short network hiccups, then returns I/O
  # errors instead of hanging Obsidian forever when the SurfVM goes away.
  # actimeo=3 keeps attribute caching short, so changes made on the SurfVM
  # show up within seconds when a note is (re)opened. Nothing on it may
  # execute here.
  fileSystems."/data/nfs/obsidian" = {
    device = "192.168.245.12:/home/hakkabara/Obsidian";
    fsType = "nfs";

    options = [
      "nfsvers=4.2"
      "nosuid"
      "nodev"
      "noexec"
      "soft"
      "timeo=150"
      "retrans=3"
      "actimeo=3"
      "_netdev"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.mount-timeout=15"
    ];
  };

  # Obsidian's Electron profile keeps a search index (with fragments of the
  # notes) and caches in ~/.config/obsidian. Remove them at every boot so no
  # note content outlives the NFS mount. Notes and vault settings live on
  # the SurfVM; obsidian.json (the vault list) stays, so the vault opens
  # again and Obsidian rebuilds the index on start.
  #
  # "Local Storage" stays: Obsidian keeps its per-device settings there,
  # among them "Override config folder" and the restricted-mode choice of a
  # vault. Without it the WorkVM falls back to the SurfVM's .obsidian folder
  # (and its plugins) after every reboot. It holds settings, not the index.
  systemd.tmpfiles.rules =
    let
      dir = "${config.users.users.${config.hakkabara.accounts.primary.username}.home}/.config/obsidian";
    in
    map (sub: ''R "${dir}/${sub}" - - - -'') [
      "IndexedDB"
      "Session Storage"
      "Cache"
      "Code Cache"
      "GPUCache"
      "DawnGraphiteCache"
      "DawnWebGPUCache"
      "Service Worker"
      "Shared Dictionary"
      "blob_storage"
    ];

  # Do not change this on normal updates.
  system.stateVersion = "26.05";
  boot.kernel.sysctl."vm.max_map_count" = 262144;

}
