{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.services.harmoniaCache;

  interface =
    if cfg.interface == null then "__harmonia_cache_interface_not_configured__" else cfg.interface;

  bindAddress = if cfg.bindAddress == null then "127.0.0.1" else cfg.bindAddress;
in
{
  options.hakkabara.services.harmoniaCache = {
    enable = lib.mkEnableOption "Harmonia Nix binary cache";

    bindAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.245.10";
      description = "IPv4 address on which Harmonia should listen.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "TCP port used by the Harmonia binary cache.";
    };

    priority = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = ''
        Binary cache priority advertised by Harmonia.
        Lower numbers have higher priority in Nix.
      '';
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ens37";
      description = "Interface on which the Harmonia firewall port is opened.";
    };

    signingKey = {
      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SOPS file containing the Harmonia cache signing key.";
      };

      secretName = lib.mkOption {
        type = lib.types.str;
        default = "harmonia-cache-signing-key";
        description = "Runtime sops-nix secret name.";
      };

      key = lib.mkOption {
        type = lib.types.str;
        default = "cache-signing-key";
        description = "Key inside the SOPS document.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bindAddress != null;
        message = ''
          hakkabara.services.harmoniaCache.bindAddress must be set.
        '';
      }

      {
        assertion = cfg.interface != null;
        message = ''
          hakkabara.services.harmoniaCache.interface must be set.
        '';
      }

      {
        assertion = cfg.signingKey.sopsFile != null;
        message = ''
          hakkabara.services.harmoniaCache.signingKey.sopsFile must be set.
        '';
      }
    ];

    sops.secrets.${cfg.signingKey.secretName} = {
      sopsFile = cfg.signingKey.sopsFile;
      key = cfg.signingKey.key;

      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.harmonia.cache = {
      enable = true;

      signKeyPaths = [
        config.sops.secrets.${cfg.signingKey.secretName}.path
      ];

      settings = {
        bind = "${bindAddress}:${toString cfg.port}";
        inherit (cfg) priority;
      };
    };

    # Harmonia uses systemd socket activation. The deployment-LAN address may
    # not yet be configured when sockets.target is reached during boot.
    # FreeBind allows the socket to bind the configured local address early.
    systemd.sockets.harmonia.socketConfig.FreeBind = true;

    # Never expose the cache port globally. Only the dedicated deployment LAN
    # may connect to Harmonia.
    networking.firewall.interfaces.${interface}.allowedTCPPorts = [
      cfg.port
    ];
  };
}
