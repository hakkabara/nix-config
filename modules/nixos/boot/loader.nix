{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.boot.loader;
in
{
  options.hakkabara.boot.loader = {
    enable = lib.mkEnableOption "declarative bootloader selection";

    backend = lib.mkOption {
      type = lib.types.enum [
        "grub"
        "systemd-boot"
      ];
      default = "systemd-boot";
      description = "Bootloader backend used by this host.";
    };

    efi.canTouchEfiVariables = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether the bootloader may modify UEFI variables.

        null leaves the NixOS default untouched. Physical UEFI hosts can
        explicitly enable this while virtual machines may leave it unset.
      '';
    };

    grub = {
      devices = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = [ "/dev/sda" ];
        description = ''
          Devices on which GRUB should be installed.

          null leaves boot.loader.grub.devices untouched so generated
          hardware configuration can provide it.
        '';
      };

      efiSupport = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable GRUB UEFI support.";
      };

      efiInstallAsRemovable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install GRUB to the standard removable/fallback EFI path.
          Useful for VMware and firmware that does not retain EFI variables.
        '';
      };

      useOSProber = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow GRUB to discover other operating systems.";
      };
    };

    systemdBoot.editor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow editing kernel command lines from the systemd-boot menu.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # A host can explicitly opt into modifying UEFI NVRAM.
      (lib.mkIf (cfg.efi.canTouchEfiVariables != null) {
        boot.loader.efi.canTouchEfiVariables = cfg.efi.canTouchEfiVariables;
      })

      # ------------------------------------------------------------
      # GRUB
      # ------------------------------------------------------------
      (lib.mkIf (cfg.backend == "grub") {
        boot.loader.systemd-boot.enable = false;

        boot.loader.grub = {
          enable = true;
          inherit (cfg.grub)
            efiSupport
            efiInstallAsRemovable
            useOSProber
            ;
        }
        // lib.optionalAttrs (cfg.grub.devices != null) {
          inherit (cfg.grub) devices;
        };
      })

      # ------------------------------------------------------------
      # systemd-boot
      # ------------------------------------------------------------
      (lib.mkIf (cfg.backend == "systemd-boot") {
        boot.loader.grub.enable = false;

        boot.loader.systemd-boot = {
          enable = true;
          inherit (cfg.systemdBoot) editor;
        };
      })
    ]
  );
}
