{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.networking.deploymentLan;

  interface =
    if cfg.interface == null then "__deployment_lan_interface_not_configured__" else cfg.interface;

  address = if cfg.ipv4.address == null then "0.0.0.0" else cfg.ipv4.address;
in
{
  options.hakkabara.networking.deploymentLan = {
    enable = lib.mkEnableOption "isolated deployment LAN";

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ens37";
      description = "Network interface connected to the deployment LAN.";
    };

    ipv4 = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.245.10";
        description = "Static IPv4 address on the deployment LAN.";
      };

      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
        description = "IPv4 prefix length for the deployment LAN.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.networkmanager.enable;
        message = ''
          hakkabara.networking.deploymentLan requires NetworkManager.
        '';
      }

      {
        assertion = cfg.interface != null;
        message = ''
          hakkabara.networking.deploymentLan.interface must be set.
        '';
      }

      {
        assertion = cfg.ipv4.address != null;
        message = ''
          hakkabara.networking.deploymentLan.ipv4.address must be set.
        '';
      }
    ];

    networking.networkmanager.ensureProfiles.profiles."hakkabara-deployment-lan" = {
      connection = {
        id = "hakkabara-deployment-lan";
        type = "ethernet";
        "interface-name" = interface;

        autoconnect = true;
        "autoconnect-priority" = 100;
      };

      ipv4 = {
        method = "manual";
        address1 = "${address}/${toString cfg.ipv4.prefixLength}";

        # The deployment LAN must never replace the normal uplink.
        "never-default" = true;

        # VMnet3 does not provide DNS.
        "ignore-auto-dns" = true;

        # A configured deployment interface is expected to come up cleanly.
        "may-fail" = false;
      };

      # Keep this isolated transport network IPv4-only for now.
      ipv6.method = "disabled";
    };
  };
}
