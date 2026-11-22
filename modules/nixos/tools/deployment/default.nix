{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.deployment;

  repoDir = "/persist/deployment/repos";
  sshDir = "/persist/deployment/ssh";

  # Runtime description for deploy-repo-sync and deploy-build. URLs may
  # point to the internal Forgejo; they are set from nix-internal, so the
  # public configuration only carries the GitHub default.
  settingsFile = pkgs.writeText "deployment.json" (
    builtins.toJSON {
      inherit repoDir;
      inherit (cfg) buildRepository;

      repositories = lib.mapAttrs (_: repo: { inherit (repo) url branch; }) cfg.repositories;

      ssh =
        if cfg.sshKey.enable then
          {
            identityFile = "${sshDir}/id_ed25519";
            configFile = "${sshDir}/config";
          }
        else
          null;
    }
  );

  runtimeEnv = {
    DEPLOYMENT_SETTINGS = settingsFile;
  };

  deployStatus = pkgs.writeShellApplication {
    name = "deploy-status";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.iproute2
      pkgs.jq
      pkgs.systemd
    ];

    inherit runtimeEnv;

    text = builtins.readFile ./scripts/deploy-status;
  };

  deployRepoSync = pkgs.writeShellApplication {
    name = "deploy-repo-sync";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.openssh
    ];

    inherit runtimeEnv;

    text = builtins.readFile ./scripts/deploy-repo-sync;
  };

  deployBuild = pkgs.writeShellApplication {
    name = "deploy-build";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
      pkgs.nix
      pkgs.openssh
    ];

    inherit runtimeEnv;

    text = builtins.readFile ./scripts/deploy-build;
  };

  repositoryType = lib.types.submodule {
    options = {
      url = lib.mkOption {
        type = lib.types.str;
        example = "ssh://forgejo@git.deploy.internal/mko/nix-config.git";
        description = "Clone URL of the managed checkout.";
      };

      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Branch the managed checkout follows.";
      };
    };
  };
in
{
  options.hakkabara.tools.deployment = {
    enable = lib.mkEnableOption "deployment helper tools";

    repositories = lib.mkOption {
      type = lib.types.attrsOf repositoryType;

      default = {
        nix-config = {
          url = "https://github.com/hakkabara/nix-config.git";
          branch = "main";
        };
      };

      description = ''
        Managed checkouts below ${repoDir}/<name>, kept up to date by
        deploy-repo-sync. A changed URL is applied to an existing clean
        checkout on the next sync.
      '';
    };

    buildRepository = lib.mkOption {
      type = lib.types.str;
      default = "nix-config";
      description = ''
        Managed checkout whose flake deploy-build evaluates. Point it at a
        private flake that extends nix-config to build the full systems.
      '';
    };

    sshKey.enable = lib.mkEnableOption ''
      a DeployVM-local SSH key for the managed checkouts. The key is
      generated once on the machine (${sshDir}/id_ed25519) and never leaves
      it; register ${sshDir}/id_ed25519.pub as a read-only deploy key.
      known_hosts is built from the local host key, because the internal
      Forgejo serves Git through this machine's own OpenSSH daemon
    '';

    sshKey.knownHostNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "git.deploy.internal" ];
      description = ''
        Host names in the repository URLs that resolve to this machine.
        They are trusted with the local ed25519 host key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repositories ? ${cfg.buildRepository};
        message = ''
          hakkabara.tools.deployment.buildRepository = "${cfg.buildRepository}"
          is not one of hakkabara.tools.deployment.repositories.
        '';
      }

      {
        assertion = lib.all (name: builtins.match "[A-Za-z0-9._-]+" name != null) (
          lib.attrNames cfg.repositories
        );
        message = ''
          hakkabara.tools.deployment.repositories names may only contain
          letters, digits, ".", "_" and "-".
        '';
      }

      {
        assertion = !cfg.sshKey.enable || cfg.sshKey.knownHostNames != [ ];
        message = ''
          hakkabara.tools.deployment.sshKey.knownHostNames must name the
          host(s) the deploy key is used for.
        '';
      }

      {
        assertion = !cfg.sshKey.enable || config.services.openssh.enable;
        message = ''
          hakkabara.tools.deployment.sshKey trusts the local host key and
          therefore needs services.openssh.enable.
        '';
      }
    ];

    systemd = {
      # Mutable deployment state belongs on the dedicated persistent Btrfs
      # subvolume rather than in the system configuration or the Nix store.
      tmpfiles.rules = [
        "d /persist/deployment 0750 mko users -"
        "d ${repoDir} 0750 mko users -"
      ]
      ++ lib.optional cfg.sshKey.enable "d ${sshDir} 0700 mko users -";

      services.deploy-ssh-key = lib.mkIf cfg.sshKey.enable {
        description = "Create the DeployVM-local SSH key for managed checkouts";

        # Forgejo provisioning reads the public key as deploy key.
        wantedBy = [
          "multi-user.target"
          "forgejo-repositories.service"
        ];
        before = [ "forgejo-repositories.service" ];
        # Host keys are generated by sshd-keygen or, on older releases, by
        # the sshd unit itself.
        after = [
          "systemd-tmpfiles-setup.service"
          "sshd-keygen.service"
          "sshd.service"
        ];

        path = [
          pkgs.coreutils
          pkgs.openssh
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "mko";
          Group = "users";
          UMask = "0077";
        };

        script = ''
          key=${sshDir}/id_ed25519

          # A crash can leave an empty private key; ssh-keygen would then ask
          # whether to overwrite it and fail on the closed stdin.
          if [ -e "$key" ] && [ ! -s "$key" ]; then
            rm -f -- "$key" "$key.pub"
          fi

          if [ ! -e "$key" ]; then
            ssh-keygen -q -t ed25519 -N "" -C "deploy-build@${config.networking.hostName}" -f "$key"
            echo "Created $key"
          fi

          if [ ! -s "$key.pub" ]; then
            ssh-keygen -y -f "$key" > "$key.pub.new"
            mv -- "$key.pub.new" "$key.pub"
            echo "Restored $key.pub"
          fi

          host_key_file=/etc/ssh/ssh_host_ed25519_key.pub
          if [ ! -s "$host_key_file" ]; then
            echo "ERROR: $host_key_file missing; is sshd running?" >&2
            exit 1
          fi
          host_key=$(cut -d " " -f 1,2 "$host_key_file")

          : > ${sshDir}/known_hosts.new
          : > ${sshDir}/config.new
          for name in ${lib.escapeShellArgs cfg.sshKey.knownHostNames}; do
            echo "$name $host_key" >> ${sshDir}/known_hosts.new
            {
              echo "Host $name"
              echo "  IdentityFile $key"
              echo "  IdentitiesOnly yes"
              echo "  UserKnownHostsFile ${sshDir}/known_hosts"
              echo "  StrictHostKeyChecking yes"
              echo "  BatchMode yes"
            } >> ${sshDir}/config.new
          done
          mv -- ${sshDir}/known_hosts.new ${sshDir}/known_hosts
          mv -- ${sshDir}/config.new ${sshDir}/config
        '';
      };

      # The Forgejo provisioning loads the public key as credential; without
      # the key unit it would fail with a credentials error instead of a clear
      # dependency failure.
      services.forgejo-repositories =
        lib.mkIf (cfg.sshKey.enable && (config.hakkabara.services.forgejo.repositories.enable or false))
          {
            requires = [ "deploy-ssh-key.service" ];
            after = [ "deploy-ssh-key.service" ];
          };
    };

    environment.systemPackages = [
      deployStatus
      deployRepoSync
      deployBuild
    ];
  };
}
