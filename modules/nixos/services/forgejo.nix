{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.services.forgejo;
  forgejoCfg = config.services.forgejo;

  interface = if cfg.interface == null then "__forgejo_interface_not_configured__" else cfg.interface;

  bindAddress = if cfg.bindAddress == null then "127.0.0.1" else cfg.bindAddress;

  # The forgejo CLI needs the same work/custom directories as the service to
  # find the generated app.ini.
  cliEnvironment = {
    USER = forgejoCfg.user;
    HOME = forgejoCfg.stateDir;
    FORGEJO_WORK_DIR = forgejoCfg.stateDir;
    FORGEJO_CUSTOM = forgejoCfg.customDir;
  };
in
{
  options.hakkabara.services.forgejo = {
    enable = lib.mkEnableOption "internal Forgejo Git server";

    bindAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.245.10";
      description = "IPv4 address on which the Forgejo web interface listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "TCP port used by the Forgejo web interface.";
    };

    interface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ens37";
      description = "Interface on which the Forgejo web port is opened.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/forgejo";
      description = ''
        Directory holding repositories, database, and configuration. It lives
        on the persistent subvolume so it survives a later move to an
        impermanent root.
      '';
    };

    dump = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Write a daily Forgejo dump below the state directory.";
      };

      age = lib.mkOption {
        type = lib.types.str;
        default = "-";
        example = "8w";
        description = ''
          Age after which old dumps are removed, in tmpfiles.d(5) syntax.
          The default "-" keeps every dump forever; free space on the state
          directory's filesystem then has to be watched manually.
        '';
      };
    };

    admin = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "mko";
        description = "Administrator account created on first start.";
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "mko@deploy-vm.internal";
        description = ''
          Mail address stored for the administrator account. Forgejo requires
          one, but no mail is ever sent from this appliance.
        '';
      };

      password = {
        sopsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "SOPS file containing the initial administrator password.";
        };

        secretName = lib.mkOption {
          type = lib.types.str;
          default = "forgejo-admin-password";
          description = "Runtime sops-nix secret name.";
        };

        key = lib.mkOption {
          type = lib.types.str;
          default = "admin-password";
          description = "Key inside the SOPS document.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bindAddress != null;
        message = ''
          hakkabara.services.forgejo.bindAddress must be set.
        '';
      }

      {
        assertion = cfg.interface != null;
        message = ''
          hakkabara.services.forgejo.interface must be set.
        '';
      }

      {
        assertion = cfg.admin.password.sopsFile != null;
        message = ''
          hakkabara.services.forgejo.admin.password.sopsFile must be set.
        '';
      }

      {
        assertion = config.services.openssh.enable;
        message = ''
          hakkabara.services.forgejo serves Git over the system OpenSSH daemon,
          so services.openssh must be enabled.
        '';
      }
    ];

    sops.secrets.${cfg.admin.password.secretName} = {
      inherit (cfg.admin.password) sopsFile key;

      owner = forgejoCfg.user;
      inherit (forgejoCfg) group;
      mode = "0400";
    };

    services.forgejo = {
      enable = true;
      inherit (cfg) stateDir;

      database.type = "sqlite3";
      lfs.enable = true;

      dump = {
        inherit (cfg.dump) enable age;
        interval = "daily";
        type = "tar.zst";
      };

      settings = {
        DEFAULT.APP_NAME = "DeployVM Git";

        server = {
          DOMAIN = bindAddress;
          HTTP_ADDR = bindAddress;
          HTTP_PORT = cfg.port;
          ROOT_URL = "http://${bindAddress}:${toString cfg.port}/";

          # Git over SSH goes through the system OpenSSH daemon as the
          # forgejo user: ssh://forgejo@<address>/<owner>/<repo>.git
          DISABLE_SSH = false;
          START_SSH_SERVER = false;
          SSH_DOMAIN = bindAddress;
          SSH_PORT = 22;
        };

        # Plain HTTP on the isolated deployment LAN only.
        session.COOKIE_SECURE = false;

        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
        };

        # Internal repositories must never start out public.
        repository = {
          DEFAULT_PRIVATE = "private";
          FORCE_PRIVATE = true;
        };

        # Pull mirrors of GitHub and of the internal GitLab. The GitLab is
        # reached over private addresses, which Forgejo blocks by default.
        mirror.ENABLED = true;
        migrations.ALLOW_LOCALNETWORKS = true;

        # No outbound side channels from the appliance.
        mailer.ENABLED = false;
        actions.ENABLED = false;
        packages.ENABLED = false;
        federation.ENABLED = false;
        other.SHOW_FOOTER_VERSION = false;
      };
    };

    # The deployment-LAN address is configured by NetworkManager and may not
    # exist yet when Forgejo starts. Restart=always in the upstream unit
    # retries the bind; do not let a slow link exhaust the start limit.
    systemd.services.forgejo = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig.RestartSec = 5;
    };

    # Create the administrator once. An existing account is left untouched, so
    # a password changed in the web interface is never reset from the secret.
    systemd.services.forgejo-admin-bootstrap = {
      description = "Create the initial Forgejo administrator";

      wantedBy = [ "multi-user.target" ];
      after = [ "forgejo.service" ];
      requires = [ "forgejo.service" ];

      path = [
        forgejoCfg.package
        pkgs.gawk
        pkgs.gnugrep
      ];

      environment = cliEnvironment;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        User = forgejoCfg.user;
        Group = forgejoCfg.group;
        WorkingDirectory = forgejoCfg.stateDir;

        LoadCredential = [
          "admin-password:${config.sops.secrets.${cfg.admin.password.secretName}.path}"
        ];
      };

      script = ''
        username=${lib.escapeShellArg cfg.admin.username}

        if forgejo admin user list | awk 'NR > 1 { print $2 }' | grep -Fqx -- "$username"; then
          echo "Forgejo administrator already exists: $username"
          exit 0
        fi

        # The forgejo CLI accepts the password only as an argument.
        forgejo admin user create \
          --admin \
          --username "$username" \
          --email ${lib.escapeShellArg cfg.admin.email} \
          --password "$(cat "$CREDENTIALS_DIRECTORY/admin-password")" \
          --must-change-password=false

        echo "Forgejo administrator created: $username"
      '';
    };

    # Never expose the web interface globally. Only the dedicated deployment
    # LAN may connect to Forgejo.
    networking.firewall.interfaces.${interface}.allowedTCPPorts = [
      cfg.port
    ];
  };
}
