{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.vmware;
in
{
  options.hakkabara.vmware = {
    enable = lib.mkEnableOption "VMware guest integration";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use the headless VMware guest integration without desktop-specific
        VMware features.
      '';
    };

    graphics.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable VMware graphics integration required by graphical guests.
      '';
    };

    sharedFolders = {
      enable = lib.mkEnableOption "VMware shared folders";

      source = lib.mkOption {
        type = lib.types.str;
        default = ".host:/";
        example = ".host:/deploy-bootstrap";
        description = ''
          VMware HGFS source to mount.

          ".host:/" exposes all shares configured for the VM. A named source
          such as ".host:/deploy-bootstrap" exposes only that share.
        '';
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/data";
        description = "Mount point for VMware shared folders.";
      };

      readOnly = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Mount the VMware shared folder read-only.";
      };

      automount.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Mount VMware shared folders on first access.";
      };

      uid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "UID used for VMware shared-folder files.";
      };

      gid = lib.mkOption {
        type = lib.types.int;
        default = 100;
        description = "GID used for VMware shared-folder files.";
      };

      umask = lib.mkOption {
        type = lib.types.str;
        default = "0033";
        description = "Umask used for VMware shared folders.";
      };

      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional vmhgfs-fuse mount options.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # VMware guests use virtual Ethernet. Physical Wi-Fi and Bluetooth
    # services are disabled by default, but hosts can override this policy
    # when hardware is deliberately passed through.
    networking.wireless.enable = lib.mkDefault false;
    hardware.bluetooth.enable = lib.mkDefault false;
    services.blueman.enable = lib.mkDefault false;

    # NixOS' native VMware integration already provides separate graphical
    # and headless open-vm-tools variants.
    virtualisation.vmware.guest = {
      enable = true;
      inherit (cfg) headless;
    };

    # Early VMware graphics support is only useful for graphical guests.
    boot.initrd.kernelModules = lib.optionals cfg.graphics.enable [
      "vmwgfx"
    ];

    # Dynamic guest resolution handling is irrelevant on headless guests.
    environment.etc = lib.mkIf cfg.graphics.enable {
      "vmware-tools/tools.conf".text = ''
        [resolutionKMS]
        enable=true
      '';
    };

    # VMware shared folders are optional and mounted lazily by default.
    #
    # Workstation VMs can continue exposing all configured shares through
    # ".host:/". Security-sensitive appliance VMs can instead select one
    # explicitly named read-only share.
    fileSystems = lib.mkIf cfg.sharedFolders.enable {
      "${cfg.sharedFolders.mountPoint}" = {
        device = cfg.sharedFolders.source;
        fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";

        options = [
          (if cfg.sharedFolders.readOnly then "ro" else "rw")
          "uid=${toString cfg.sharedFolders.uid}"
          "gid=${toString cfg.sharedFolders.gid}"
          "umask=${cfg.sharedFolders.umask}"
          "allow_other"
          "auto_unmount"
          "nofail"
        ]
        ++ lib.optional cfg.sharedFolders.automount.enable "x-systemd.automount"
        ++ cfg.sharedFolders.extraOptions;
      };
    };

    # Xorg userspace driver is unnecessary on headless appliance VMs.
    environment.systemPackages = lib.optionals cfg.graphics.enable [
      pkgs.xf86-video-vmware
    ];
  };
}
