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

  domain = if cfg.domain == null then bindAddress else cfg.domain;

  # With TLS, nginx owns the public address and Forgejo moves to loopback.
  httpAddress = if cfg.tls.enable then "127.0.0.1" else bindAddress;

  apiUrl = "http://${httpAddress}:${toString cfg.port}/api/v1";

  tokenFile = "${cfg.stateDir}/provisioning/token";

  mirrorSync = pkgs.writeShellApplication {
    name = "forgejo-mirror-sync";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];

    runtimeEnv = {
      FORGEJO_API = apiUrl;
      ADMIN_USER = cfg.admin.username;
      TOKEN_FILE = tokenFile;
    };

    text = builtins.readFile ./forgejo-mirror-sync.sh;
  };

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

    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "git.deploy.internal";
      description = ''
        Host name clients use for web and Git over SSH URLs. Defaults to
        the bind address.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = ''
        TCP port used by the Forgejo web interface. With TLS enabled it is
        bound to 127.0.0.1 only and reached through nginx.
      '';
    };

    tls = {
      enable = lib.mkEnableOption ''
        HTTPS on port 443 through an nginx reverse proxy. Forgejo itself then
        listens on 127.0.0.1 only and its plain HTTP port is closed
      '';

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS YAML document holding the PEM server certificate (including
          intermediates) and its private key.
        '';
      };

      certificateKey = lib.mkOption {
        type = lib.types.str;
        default = "certificate";
        description = "Key of the PEM certificate chain inside the SOPS document.";
      };

      privateKeyKey = lib.mkOption {
        type = lib.types.str;
        default = "private-key";
        description = "Key of the PEM private key inside the SOPS document.";
      };
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

    repositories = {
      enable = lib.mkEnableOption ''
        declarative repositories, pull mirrors and administrator SSH keys.
        Everything, including names, upstream URLs and credentials, lives in
        an encrypted SOPS document so none of it appears in the public
        configuration
      '';

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          SOPS YAML document describing the repositories:

              repositories:
                - name: <name>          # becomes <admin>/<name>
                  enable: true          # optional, default true
                  description: "..."    # optional
                  mirror:               # optional, omit for a plain repository
                    url: https://...
                    interval: 1h        # optional, Go duration, minimum 10m
                    username: ...       # optional
                    password: ...       # optional, password or access token

              sshKeys:
                - title: <title>        # stored as "nixos:<title>"
                  key: ssh-ed25519 AAAA...

          Lists are used on purpose: SOPS encrypts only values, so mapping
          keys such as repository names would stay readable.

          SSH keys are added to the administrator account. Keys titled
          "nixos:*" that are missing from the document are removed, so a
          key is revoked by deleting it here. Keys added through the web
          interface stay untouched.

          Missing repositories are created private. Existing ones get
          description and mirror interval reconciled; a changed mirror URL
          has no effect on them. Entries removed from the document are never
          deleted.
        '';
      };

      secretName = lib.mkOption {
        type = lib.types.str;
        default = "forgejo-repositories";
        description = "Runtime sops-nix secret name.";
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
        assertion = !cfg.repositories.enable || cfg.repositories.sopsFile != null;
        message = ''
          hakkabara.services.forgejo.repositories.sopsFile must be set.
        '';
      }

      {
        assertion = !cfg.tls.enable || cfg.tls.sopsFile != null;
        message = ''
          hakkabara.services.forgejo.tls.sopsFile must be set.
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

    sops.secrets = {
      forgejo-tls-certificate = lib.mkIf cfg.tls.enable {
        inherit (cfg.tls) sopsFile;
        key = cfg.tls.certificateKey;

        owner = config.services.nginx.user;
        inherit (config.services.nginx) group;
        mode = "0400";
      };

      forgejo-tls-private-key = lib.mkIf cfg.tls.enable {
        inherit (cfg.tls) sopsFile;
        key = cfg.tls.privateKeyKey;

        owner = config.services.nginx.user;
        inherit (config.services.nginx) group;
        mode = "0400";
      };

      ${cfg.admin.password.secretName} = {
        inherit (cfg.admin.password) sopsFile key;

        owner = forgejoCfg.user;
        inherit (forgejoCfg) group;
        mode = "0400";
      };

      # The complete decrypted document (key = ""). Only root can read it;
      # the provisioning unit receives it as a systemd credential.
      ${cfg.repositories.secretName} = lib.mkIf cfg.repositories.enable {
        inherit (cfg.repositories) sopsFile;
        format = "yaml";
        key = "";
        mode = "0400";
      };
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
          DOMAIN = domain;
          HTTP_ADDR = httpAddress;
          HTTP_PORT = cfg.port;
          ROOT_URL =
            if cfg.tls.enable then "https://${domain}/" else "http://${domain}:${toString cfg.port}/";

          # Git over SSH goes through the system OpenSSH daemon as the
          # forgejo user: ssh://forgejo@<address>/<owner>/<repo>.git
          DISABLE_SSH = false;
          START_SSH_SERVER = false;
          SSH_DOMAIN = domain;
          SSH_PORT = 22;
        };

        # Without TLS: plain HTTP on the isolated deployment LAN only.
        session.COOKIE_SECURE = cfg.tls.enable;

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

    systemd.services = {
      # The deployment-LAN address is configured by NetworkManager and may not
      # exist yet when Forgejo starts. Restart=always in the upstream unit
      # retries the bind; do not let a slow link exhaust the start limit.
      forgejo = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig.RestartSec = 5;
      };

      # Same deployment-LAN address race as Forgejo. Reload the certificate
      # when the encrypted document changes (replaces sops-nix restartUnits).
      nginx = lib.mkIf cfg.tls.enable {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        restartTriggers = [ (builtins.hashFile "sha256" cfg.tls.sopsFile) ];

        # The nginx module limits restarts to a 60 s window.
        startLimitIntervalSec = lib.mkForce 0;
      };

      # Create the administrator once. An existing account is left untouched, so
      # a password changed in the web interface is never reset from the secret.
      forgejo-admin-bootstrap = {
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

      # Reconcile the repositories from the SOPS document through the HTTP API.
      # A dedicated access token for this service is created with the forgejo
      # CLI and kept in the state directory; it is regenerated when it stops
      # working.
      forgejo-repositories = lib.mkIf cfg.repositories.enable {
        description = "Provision declared Forgejo repositories and SSH keys";

        wantedBy = [ "multi-user.target" ];
        after = [ "forgejo-admin-bootstrap.service" ];
        requires = [ "forgejo-admin-bootstrap.service" ];

        # Re-run on every switch that changes the encrypted document. This
        # replaces sops-nix restartUnits, which restarts units from the
        # activation script (deprecated, removed in NixOS 26.11).
        # Hash the file itself: the path alone would change with every commit.
        restartTriggers = [ (builtins.hashFile "sha256" cfg.repositories.sopsFile) ];

        path = [
          forgejoCfg.package
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.yq-go
        ];

        environment = cliEnvironment // {
          FORGEJO_API = apiUrl;
          ADMIN_USER = cfg.admin.username;
          TOKEN_FILE = tokenFile;
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;

          User = forgejoCfg.user;
          Group = forgejoCfg.group;
          WorkingDirectory = forgejoCfg.stateDir;
          UMask = "0077";

          LoadCredential = [
            "repositories:${config.sops.secrets.${cfg.repositories.secretName}.path}"
          ];
        };

        script = builtins.readFile ./forgejo-repositories.sh;
      };
    };

    # On-demand mirror update before builds, using the provisioning token.
    environment.systemPackages = lib.mkIf cfg.repositories.enable [ mirrorSync ];

    # Never expose the web interface globally. Only the dedicated deployment
    # LAN may connect to Forgejo.
    networking.firewall.interfaces.${interface}.allowedTCPPorts = [
      (if cfg.tls.enable then 443 else cfg.port)
    ];

    services.nginx = lib.mkIf cfg.tls.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;

      virtualHosts.${domain} = {
        default = true;
        onlySSL = true;

        listen = [
          {
            addr = bindAddress;
            port = 443;
            ssl = true;
          }
        ];

        sslCertificate = config.sops.secrets.forgejo-tls-certificate.path;
        sslCertificateKey = config.sops.secrets.forgejo-tls-private-key.path;

        locations."/" = {
          proxyPass = "http://${httpAddress}:${toString cfg.port}";

          # Large pushes and LFS uploads.
          extraConfig = ''
            client_max_body_size 512M;
          '';
        };
      };
    };
  };
}
