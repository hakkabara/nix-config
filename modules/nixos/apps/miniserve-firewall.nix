{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.miniserveFirewall;

  # Fixed port, no arguments besides open/close: the sudo rule below must
  # not let the user open arbitrary ports.
  helper = pkgs.writeShellApplication {
    name = "miniserve-firewall";

    runtimeInputs = [ pkgs.iptables ];

    text = ''
      rule=(nixos-fw -p tcp --dport ${toString cfg.port} -j nixos-fw-accept)

      case "''${1:-}" in
        open)
          for ipt in iptables ip6tables; do
            "$ipt" -C "''${rule[@]}" 2>/dev/null || "$ipt" -I "''${rule[@]}"
          done
          ;;
        close)
          for ipt in iptables ip6tables; do
            while "$ipt" -D "''${rule[@]}" 2>/dev/null; do :; done
          done
          ;;
        *)
          echo "usage: miniserve-firewall open|close" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  options.hakkabara.apps.miniserveFirewall = {
    enable = lib.mkEnableOption "on-demand firewall opening for the miniserve share command";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8443;
      description = "TCP port the share command (miniserve) listens on.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "User allowed to open and close the port via sudo without a password.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.firewall.enable && !config.networking.nftables.enable;
        message = "hakkabara.apps.miniserveFirewall expects the iptables-based NixOS firewall.";
      }
    ];

    environment.systemPackages = [ helper ];

    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          {
            command = "/run/current-system/sw/bin/miniserve-firewall open";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/miniserve-firewall close";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
