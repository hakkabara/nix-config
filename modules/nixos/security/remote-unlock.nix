{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.security.remoteUnlock;

  useStatic = cfg.network.mode == "static";

  restrictedAuthorizedKeys = map (
    key:
    if cfg.restrictToUnlock then
      ''no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc,command="systemctl default" ${key}''
    else
      key
  ) cfg.authorizedKeys;

  hardenedSshConfig = lib.optionalString cfg.hardening.enable ''
    PermitRootLogin prohibit-password
    KbdInteractiveAuthentication no
    AllowAgentForwarding no
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    X11Forwarding no
    PermitTunnel no
    GatewayPorts no
    PermitUserEnvironment no
    MaxAuthTries 3
  '';
in
{
  options.hakkabara.security.remoteUnlock = {
    enable = lib.mkEnableOption "SSH based remote LUKS unlock in the initrd";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "SSH port exposed during the initrd.";
    };

    restrictToUnlock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Restrict SSH keys to the systemd initrd unlock flow instead of
        providing a general-purpose initrd root shell.
      '';
    };

    hardening.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply hardened SSH defaults to the initrd SSH server.";
    };

    extraSshConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional OpenSSH configuration for initrd SSH.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."
      ];
      description = ''
        Public SSH keys allowed to connect to the initrd SSH server.
      '';
    };

    network = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "dhcp"
          "static"
        ];
        default = "dhcp";
        description = "Initrd network addressing mode.";
      };

      interface = lib.mkOption {
        type = lib.types.str;
        default = "ens160";
        example = "eno1";
        description = ''
          Network interface used in the initrd.
          ens160 is the convenient VMware default and can be overridden.
        '';
      };

      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.1.50";
        description = "Static IPv4 address used in the initrd.";
      };

      prefixLength = lib.mkOption {
        type = lib.types.ints.between 0 32;
        default = 24;
        description = "Static IPv4 prefix length.";
      };

      gateway = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.1.1";
        description = "Optional static IPv4 gateway.";
      };

      kernelModules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "vmxnet3" ];
        description = ''
          Additional network drivers which must be available in the initrd.
        '';
      };
    };

    hostKey = {
      manageWithSops = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Manage the dedicated initrd SSH host private key with sops-nix.
        '';
      };

      secretName = lib.mkOption {
        type = lib.types.str;
        default = "initrd-ssh-host-key";
        description = "sops-nix secret name for the initrd SSH host key.";
      };

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "./secrets/initrd-ssh-host-key.sops";
        description = ''
          SOPS encrypted file containing the dedicated initrd SSH host key.
        '';
      };

      sopsFormat = lib.mkOption {
        type = lib.types.enum [
          "binary"
          "yaml"
          "json"
          "ini"
          "dotenv"
        ];
        default = "binary";
        description = "SOPS file format used for the initrd SSH host key.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/etc/secrets/initrd/ssh_host_ed25519_key";
        description = ''
          Runtime path of the private SSH host key which is copied into
          the initrd.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.authorizedKeys != [ ];
            message = ''
              hakkabara.security.remoteUnlock.authorizedKeys must contain
              at least one SSH public key.
            '';
          }

          {
            assertion = !cfg.hostKey.manageWithSops || cfg.hostKey.sopsFile != null;
            message = ''
              hakkabara.security.remoteUnlock.hostKey.sopsFile must be set
              when manageWithSops = true.
            '';
          }

          {
            assertion = !useStatic || cfg.network.address != null;
            message = ''
              hakkabara.security.remoteUnlock.network.address must be set
              when network.mode = "static".
            '';
          }
        ];

        boot.initrd = {
          systemd.enable = true;

          availableKernelModules = cfg.network.kernelModules;

          network = {
            enable = true;

            ssh = {
              enable = true;
              inherit (cfg) port;

              hostKeys = [
                cfg.hostKey.path
              ];

              authorizedKeys = restrictedAuthorizedKeys;

              extraConfig = ''
                ${hardenedSshConfig}
                ${cfg.extraSshConfig}
              '';
            };
          };

          systemd.network = {
            enable = true;

            networks."10-remote-unlock" = {
              matchConfig.Name = cfg.network.interface;

              linkConfig.RequiredForOnline = "routable";

              networkConfig = lib.optionalAttrs (!useStatic) {
                DHCP = "ipv4";
              };

              address = lib.optionals useStatic [
                "${cfg.network.address}/${toString cfg.network.prefixLength}"
              ];

              routes = lib.optionals (useStatic && cfg.network.gateway != null) [
                {
                  Gateway = cfg.network.gateway;
                }
              ];
            };
          };
        };
      }

      (lib.mkIf (cfg.hostKey.manageWithSops && cfg.hostKey.sopsFile != null) {
        sops.secrets.${cfg.hostKey.secretName} = {
          sopsFile = cfg.hostKey.sopsFile;
          format = cfg.hostKey.sopsFormat;

          path = cfg.hostKey.path;

          owner = "root";
          group = "root";
          mode = "0400";
        };
      })
    ]
  );
}
