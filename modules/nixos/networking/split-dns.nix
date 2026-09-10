{
  config,
  lib,
  ...
}:

let
  cfg = config.hakkabara.networking.splitDns;
in
{
  options.hakkabara.networking.splitDns = {
    enable = lib.mkEnableOption "local split-DNS resolver";

    publicResolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;

      default = [
        "185.222.222.222"
        "45.11.45.11"
      ];

      description = ''
        Public upstream DNS resolvers used for all queries that do not match
        a private domain-specific rule.
      '';
    };

    privateConfigFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;

      description = ''
        Runtime-only dnsmasq configuration file containing private split-DNS
        forwarding rules. Intended to point at a file provided by sops-nix.

        Example syntax inside the secret:

          server=/internal.example/10.0.0.53
          server=/other.internal/10.1.0.53

        Real internal names and resolver addresses must not be placed in this
        public module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.privateConfigFile != null;
        message = ''
          hakkabara.networking.splitDns.privateConfigFile must be set when
          split DNS is enabled.
        '';
      }
    ];

    services.dnsmasq = {
      enable = true;

      # NixOS makes the local dnsmasq instance the system resolver.
      resolveLocalQueries = true;

      settings = {
        # Resolver is local to this VM only. Nothing listens on the VM network
        # interface and no DNS firewall port is required.
        listen-address = [
          "127.0.0.1"
          "::1"
        ];

        bind-interfaces = true;

        # Never inherit DHCP/VPN DNS servers as generic upstream resolvers.
        # Public DNS and private split rules below are explicit.
        no-resolv = true;

        cache-size = 4096;

        server = cfg.publicResolvers;

        # Domain-specific internal forwarding rules live only in the
        # runtime-decrypted sops-nix file.
        conf-file = lib.optional (cfg.privateConfigFile != null) cfg.privateConfigFile;
      };
    };
  };
}
