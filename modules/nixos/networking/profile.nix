{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.networking;

  useNetworkd = cfg.backend == "networkd";
  useStatic = cfg.mode == "static";

  interface = if cfg.interface == null then "__interface_not_configured__" else cfg.interface;
in
{
  options.hakkabara.networking = {
    enable = lib.mkEnableOption "shared host networking profile";

    backend = lib.mkOption {
      type = lib.types.enum [
        "networkmanager"
        "networkd"
      ];
      default = "networkmanager";
      description = ''
        Network backend.

        Desktop/workstation hosts normally use NetworkManager.
        Servers and appliances can override this to systemd-networkd.
      '';
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "dhcp"
        "static"
      ];
      default = "dhcp";
      description = "IPv4 configuration mode.";
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ens160";
      description = ''
        Network interface to configure.

        Required for the networkd backend and static addressing.
      '';
    };

    ipv4 = {
      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.1.50";
        description = "Static IPv4 address.";
      };

      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
        description = "IPv4 prefix length.";
      };

      gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.1.1";
        description = "Optional IPv4 default gateway.";
      };

      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "192.168.1.1"
          "1.1.1.1"
        ];
        description = "DNS servers for static addressing.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !useNetworkd || cfg.interface != null;
            message = ''
              hakkabara.networking.interface must be set when using
              hakkabara.networking.backend = "networkd".
            '';
          }

          {
            assertion = !useStatic || useNetworkd;
            message = ''
              Static addressing currently requires
              hakkabara.networking.backend = "networkd".
            '';
          }

          {
            assertion = !useStatic || cfg.interface != null;
            message = ''
              hakkabara.networking.interface must be set for static addressing.
            '';
          }

          {
            assertion = !useStatic || cfg.ipv4.address != null;
            message = ''
              hakkabara.networking.ipv4.address must be set for static addressing.
            '';
          }
        ];
      }

      # Desktop/workstation default.
      (lib.mkIf (!useNetworkd) {
        networking.networkmanager.enable = lib.mkDefault true;
      })

      # Headless/server backend.
      (lib.mkIf useNetworkd {
        networking = {
          networkmanager.enable = lib.mkForce false;
          useNetworkd = true;
          useDHCP = false;
        };

        systemd.network = {
          enable = true;

          networks."10-hakkabara" = {
            matchConfig.Name = interface;

            linkConfig.RequiredForOnline = "routable";

            networkConfig = lib.optionalAttrs (!useStatic) {
              DHCP = "ipv4";
            };

            address = lib.optionals useStatic [
              "${cfg.ipv4.address}/${toString cfg.ipv4.prefixLength}"
            ];

            routes = lib.optionals (useStatic && cfg.ipv4.gateway != null) [
              {
                Gateway = cfg.ipv4.gateway;
              }
            ];
          };
        };
      })

      (lib.mkIf (useStatic && cfg.ipv4.dns != [ ]) {
        networking.nameservers = cfg.ipv4.dns;
      })
    ]
  );
}
