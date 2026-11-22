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

  fqdn = name: "${name}.${cfg.domain}";

  hostModule = {
    options = {
      address = lib.mkOption {
        type = lib.types.str;
        example = "192.168.245.10";
        description = "IPv4 address of the host on the deployment LAN.";
      };

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "git" ];
        description = "Additional service names below the deployment domain.";
      };
    };
  };
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

    domain = lib.mkOption {
      type = lib.types.str;
      default = "deploy.internal";
      description = ''
        Name suffix for hosts and services on the deployment LAN. The
        .internal TLD is reserved for private use and never resolves
        publicly.
      '';
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule hostModule);
      default = import ./deployment-lan-hosts.nix;
      defaultText = lib.literalExpression "import ./deployment-lan-hosts.nix";
      description = ''
        Hosts on the deployment LAN. Each becomes <name>.<domain> plus
        <alias>.<domain> for every alias in /etc/hosts.
      '';
    };

    caCertificate = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "../../keys/deploy-lan-ca.crt";
      description = ''
        PEM certificate of the internal CA that signs the HTTPS certificates
        of services on the deployment LAN. Added to the system trust store.
        The CA is name-constrained to the deployment domain and LAN.
      '';
    };

    ipv4 = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = cfg.hosts.${config.networking.hostName}.address or null;
        defaultText = lib.literalExpression "hosts.\${config.networking.hostName}.address";
        example = "192.168.245.10";
        description = ''
          Static IPv4 address on the deployment LAN. Taken from the host
          table by default.
        '';
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

    security.pki.certificateFiles = lib.optional (cfg.caCertificate != null) cfg.caCertificate;

    networking.hosts = lib.mapAttrs' (
      name: host: lib.nameValuePair host.address (map fqdn ([ name ] ++ host.aliases))
    ) cfg.hosts;

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

        # The "deployment" VMware network does not provide DNS.
        "ignore-auto-dns" = true;

        # A configured deployment interface is expected to come up cleanly.
        "may-fail" = false;
      };

      # Keep this isolated transport network IPv4-only for now.
      ipv6.method = "disabled";
    };
  };
}
