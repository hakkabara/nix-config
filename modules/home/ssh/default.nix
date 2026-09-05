{ config, lib, ... }:

{
  # Persistent per-user OpenSSH agent.
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Local machine-specific/customer configuration.
    #
    # Files below ~/.ssh/config.d/ are intentionally NOT managed by
    # Home Manager so customer systems can be added/changed immediately
    # without touching Git, SOPS or rebuilding NixOS.
    includes = lib.mkBefore [
      "${config.home.homeDirectory}/.ssh/config.d/*.conf"
    ];

    settings."*" = {
      ForwardAgent = false;
      ForwardX11 = false;

      AddKeysToAgent = "yes";

      ServerAliveInterval = 30;
      ServerAliveCountMax = 3;
      ConnectTimeout = 10;

      HashKnownHosts = true;
      UpdateHostKeys = true;
    };
  };

  # Create only the directory. Files inside remain user-managed.
  home.activation.ensureSshConfigDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.home.homeDirectory}/.ssh/config.d"
    chmod 700 "${config.home.homeDirectory}/.ssh"
    chmod 700 "${config.home.homeDirectory}/.ssh/config.d"
  '';
}
