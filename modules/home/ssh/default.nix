{ config, lib, ... }:

let
  cfg = config.hakkabara.ssh;
  localConfigDir = "${config.home.homeDirectory}/.ssh/config.d";
in
{
  options.hakkabara.ssh = {
    enable = lib.mkEnableOption "shared OpenSSH client configuration";

    agent.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the per-user OpenSSH authentication agent.";
    };

    defaults.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable shared safe OpenSSH client defaults.";
    };

    localConfig.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include locally editable SSH configuration fragments.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.ssh = {
          enable = true;
          enableDefaultConfig = false;
        };
      }

      (lib.mkIf cfg.agent.enable {
        services.ssh-agent.enable = true;
      })

      (lib.mkIf cfg.defaults.enable {
        programs.ssh.settings."*" = {
          ForwardAgent = false;
          ForwardX11 = false;

          AddKeysToAgent = "yes";

          ServerAliveInterval = 30;
          ServerAliveCountMax = 3;
          ConnectTimeout = 10;

          HashKnownHosts = true;
          UpdateHostKeys = true;
        };
      })

      (lib.mkIf cfg.localConfig.enable {
        programs.ssh.includes = lib.mkBefore [
          "${localConfigDir}/*.conf"
        ];

        # Create only the directory. Files inside remain user-managed.
        home.activation.ensureSshConfigDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "${localConfigDir}"
          chmod 700 "${config.home.homeDirectory}/.ssh"
          chmod 700 "${localConfigDir}"
        '';
      })
    ]
  );
}
