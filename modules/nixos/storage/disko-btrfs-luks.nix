{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.storage.disko;

  commonBtrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  options.hakkabara.storage.disko = {
    enable = lib.mkEnableOption "Disko-managed single-disk LUKS2 + Btrfs layout";

    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/disk/by-id/wwn-...";
      description = ''
        Target disk used outside disko-install. During installation,
        disko-install can override this with --disk main /dev/....
      '';
    };

    luksName = lib.mkOption {
      type = lib.types.str;
      default = "crypted";
      description = "Name of the LUKS mapper device.";
    };

    espSize = lib.mkOption {
      type = lib.types.str;
      default = "1G";
      description = "Size of the EFI system partition.";
    };

    allowDiscards = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow discard/TRIM through LUKS. Useful for VM thin-provisioned disks,
        but leaks which encrypted blocks are unused.
      '';
    };

    swap = {
      enable = lib.mkEnableOption "encrypted Btrfs swapfile" // {
        default = true;
      };

      size = lib.mkOption {
        type = lib.types.str;
        default = "8G";
        description = "Size of the swapfile inside the encrypted Btrfs filesystem.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Hybrid GPT layout: BIOS GRUB partition + EFI System Partition.
    # This keeps the same layout usable in VMware regardless of whether
    # the VM firmware is configured for legacy BIOS or UEFI.
    disko.devices.disk.main = {
      type = "disk";
      inherit (cfg) device;

      content = {
        type = "gpt";

        partitions = {
          boot = {
            priority = 1;
            size = "1M";
            type = "EF02";
            attributes = [ 0 ];
          };

          ESP = {
            priority = 2;
            size = cfg.espSize;
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            size = "100%";

            content = {
              type = "luks";
              name = cfg.luksName;

              # No passwordFile/keyFile on purpose. Disko therefore asks for
              # the initial LUKS password interactively during formatting.
              settings.allowDiscards = cfg.allowDiscards;

              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];

                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = commonBtrfsMountOptions;
                  };

                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = commonBtrfsMountOptions;
                  };

                  # Prepared now, intentionally unused until Impermanence is
                  # introduced later.
                  "/persist" = {
                    mountpoint = "/persist";
                    mountOptions = commonBtrfsMountOptions;
                  };
                }
                // lib.optionalAttrs cfg.swap.enable {
                  "/swap" = {
                    mountpoint = "/.swapvol";
                    swap.swapfile.size = cfg.swap.size;
                  };
                };
              };
            };
          };
        };
      };
    };

    # Disko's hybrid GPT recommendation: GRUB can boot this layout from both
    # legacy BIOS and UEFI. disko-install supplies the concrete GRUB disk from
    # its --disk mapping during installation.
    boot.loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      useOSProber = false;
    };

    # /persist is already considered early-boot storage so a later
    # Impermanence migration does not require changing the disk layout.
    fileSystems."/persist".neededForBoot = true;

    # Periodic trim is preferable to permanent discard mount options here.
    services.fstrim.enable = cfg.allowDiscards;
  };
}
