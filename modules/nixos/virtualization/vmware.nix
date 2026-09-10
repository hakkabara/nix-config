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

    sharedFolders = {
      enable = lib.mkEnableOption "VMware shared folders";

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/data";
        description = "Mount point for VMware shared folders.";
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

    # NixOS' official VMware guest integration.
    virtualisation.vmware.guest = {
      enable = true;
      headless = false;
    };

    # Early VMware graphics support.
    boot.initrd.kernelModules = [
      "vmwgfx"
    ];

    # Let VMware Tools use KMS for dynamic guest resolution handling.
    environment.etc."vmware-tools/tools.conf".text = ''
      [resolutionKMS]
      enable=true
    '';

    # VMware shared folders are optional and mounted lazily by default.
    #
    # Mounting .host:/ exposes every share configured in VMware below the
    # selected mount point without requiring per-share Nix configuration.
    fileSystems = lib.mkIf cfg.sharedFolders.enable {
      "${cfg.sharedFolders.mountPoint}" = {
        device = ".host:/";
        fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";

        options = [
          "rw"
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

    # Xorg userspace driver for X11/XWayland compatibility.
    environment.systemPackages = with pkgs; [
      xf86-video-vmware
    ];
  };
}
