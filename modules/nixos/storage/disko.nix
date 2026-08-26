{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.storage.disko;

  btrfsMountOptions =
    lib.optional (cfg.btrfs.compression != null) "compress=${cfg.btrfs.compression}"
    ++ lib.optional cfg.btrfs.noatime "noatime";

  ext4MountOptions = lib.optional cfg.ext4.noatime "noatime";

  btrfsContent = {
    type = "btrfs";
    extraArgs = [ "-f" ];

    subvolumes = {
      "/root" = {
        mountpoint = "/";
        mountOptions = btrfsMountOptions;
      };

      "/nix" = {
        mountpoint = "/nix";
        mountOptions = btrfsMountOptions;
      };
    }
    // lib.optionalAttrs cfg.btrfs.prepareForImpermanence {
      "/persist" = {
        mountpoint = "/persist";
        mountOptions = btrfsMountOptions;
      };
    }
    // lib.optionalAttrs cfg.swap.enable {
      "/swap" = {
        mountpoint = "/.swapvol";
        swap.swapfile.size = "${toString cfg.swap.sizeMiB}M";
      };
    };
  };

  ext4Content = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
    mountOptions = ext4MountOptions;
  };

  filesystemContent = if cfg.filesystem == "btrfs" then btrfsContent else ext4Content;

  systemContent =
    if cfg.encryption.enable then
      {
        type = "luks";
        name = cfg.encryption.name;
        passwordFile = cfg.encryption.installPasswordFile;

        # No passwordFile/keyFile:
        # initial LUKS setup asks interactively for a password.
        settings = {
          allowDiscards = cfg.encryption.allowDiscards;
        }
        // lib.optionalAttrs cfg.encryption.yubikey.enable {
          # Enrollment is performed separately with systemd-cryptenroll.
          # This only configures early boot to use the enrolled FIDO2 token.
          crypttabExtraOpts = [
            "fido2-device=${cfg.encryption.yubikey.device}"
            "token-timeout=${cfg.encryption.yubikey.tokenTimeout}"
          ];
        };

        content = filesystemContent;
      }
    else
      filesystemContent;
in
{
  options.hakkabara.storage.disko = {
    enable = lib.mkEnableOption "Disko-managed single-disk storage layout";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      example = "/dev/disk/by-id/wwn-...";
      description = ''
        Target disk used outside disko-install. During installation,
        disko-install can override this with --disk main /dev/....
      '';
    };

    filesystem = lib.mkOption {
      type = lib.types.enum [
        "btrfs"
        "ext4"
      ];
      default = "btrfs";
      description = "Filesystem used for the system partition.";
    };

    boot = {
      biosCompatibility = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Add a BIOS boot partition in addition to the EFI System Partition,
          allowing the same GPT layout to boot in VMware BIOS or UEFI mode.
        '';
      };

      espSize = lib.mkOption {
        type = lib.types.str;
        default = "1G";
        description = "Size of the EFI System Partition.";
      };
    };

    partition.systemSize = lib.mkOption {
      type = lib.types.str;
      default = "100%";
      description = ''
        Size of the system partition. "100%" uses all remaining disk space.
        Fixed Disko/sgdisk sizes such as "80G" can also be used.
      '';
    };

    encryption = {
      enable = lib.mkEnableOption "LUKS2 encryption" // {
        default = true;
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "crypted";
        description = "Name of the LUKS mapper device.";
      };

      installPasswordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/tmp/disko-luks-password";
        description = ''
          Optional password file used only when initially creating LUKS.
          Intended for installers such as nixos-anywhere. The file is not
          required for normal boot or runtime unlocking.
        '';
      };

      allowDiscards = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Allow discard/TRIM requests through LUKS. Useful for thin-provisioned
          VM disks, but reveals which encrypted blocks are unused.
        '';
      };

      yubikey = {
        enable = lib.mkEnableOption "YubiKey/FIDO2 LUKS unlocking";

        device = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = ''
            FIDO2 device used during early boot. "auto" automatically discovers
            a compatible enrolled FIDO2 token.
          '';
        };

        tokenTimeout = lib.mkOption {
          type = lib.types.str;
          default = "10s";
          example = "20s";
          description = ''
            How long systemd waits for the FIDO2 token before falling back
            to another LUKS unlock method such as the normal password.
          '';
        };

      };
    };

    btrfs = {
      compression = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "zstd";
        description = ''
          Btrfs compression algorithm. Set to null to disable compression.
        '';
      };

      noatime = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Mount Btrfs subvolumes with noatime.";
      };

      prepareForImpermanence = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Create a persistent /persist Btrfs subvolume now so Impermanence can
          be introduced later without repartitioning or reinstalling.
          This does not itself enable Impermanence.
        '';
      };
    };

    ext4.noatime = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mount ext4 with noatime.";
    };

    swap = {
      enable = lib.mkEnableOption "swapfile" // {
        default = true;
      };

      sizeMiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8192;
        description = "Swapfile size in MiB.";
      };
    };

    trim.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable periodic filesystem TRIM.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !cfg.encryption.yubikey.enable || cfg.encryption.enable;
            message = ''
              hakkabara.storage.disko.encryption.yubikey.enable requires
              hakkabara.storage.disko.encryption.enable = true.
            '';
          }
        ];

        disko.devices.disk.main = {
          type = "disk";
          inherit (cfg) device;

          content = {
            type = "gpt";

            partitions =
              lib.optionalAttrs cfg.boot.biosCompatibility {
                boot = {
                  priority = 1;
                  size = "1M";
                  type = "EF02";
                  attributes = [ 0 ];
                };
              }
              // {
                ESP = {
                  priority = 2;
                  size = cfg.boot.espSize;
                  type = "EF00";

                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };

                system = {
                  size = cfg.partition.systemSize;
                  content = systemContent;
                };
              };
          };
        };

        boot.loader.grub = {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
          useOSProber = false;
        };

        services.fstrim.enable = cfg.trim.enable;
      }

      # FIDO2 unlocking requires the systemd-based initrd.
      (lib.mkIf cfg.encryption.yubikey.enable {
        boot.initrd.systemd.enable = true;
      })

      # /persist only exists in our Btrfs layout.
      (lib.mkIf (cfg.filesystem == "btrfs" && cfg.btrfs.prepareForImpermanence) {
        fileSystems."/persist".neededForBoot = true;
      })

      # Disko has native Btrfs swapfile support. For ext4, let NixOS create
      # the swapfile inside the root filesystem.
      (lib.mkIf (cfg.filesystem == "ext4" && cfg.swap.enable) {
        swapDevices = [
          {
            device = "/swapfile";
            size = cfg.swap.sizeMiB;
          }
        ];
      })
    ]
  );
}
