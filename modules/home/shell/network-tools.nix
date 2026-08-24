{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hakkabara.shell.networkTools;

  myIp = pkgs.writeShellApplication {
    name = "myip";

    runtimeInputs = [
      pkgs.curl
      pkgs.iproute2
    ];

    text = ''
      default_endpoints=(
        "https://api.ipify.org"
        "https://ifconfig.co/ip"
        "https://icanhazip.com"
      )

      # Internal override used by deterministic tests and troubleshooting.
      if [[ -n "''${MYIP_ENDPOINTS:-}" ]]; then
        read -r -a endpoints <<< "$MYIP_ENDPOINTS"
      else
        endpoints=("''${default_endpoints[@]}")
      fi

      for endpoint in "''${endpoints[@]}"; do
        candidate="$(
          curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --connect-timeout 2 \
            --max-time 5 \
            "$endpoint" \
            2>/dev/null || true
        )"

        candidate="''${candidate//$'\r'/}"
        candidate="''${candidate//$'\n'/}"
        candidate="''${candidate//$'\t'/}"
        candidate="''${candidate// /}"

        [[ -n "$candidate" ]] || continue

        # `ip route get` rejects malformed address strings without sending
        # traffic, so an HTML/error response can never be printed as an IP.
        if ip route get "$candidate" >/dev/null 2>&1; then
          printf '%s\n' "$candidate"
          exit 0
        fi
      done

      echo "ERROR: unable to determine public IP" >&2
      exit 1
    '';
  };

  netcheck = pkgs.writeShellApplication {
    name = "netcheck";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
      myIp
    ];

    text = ''
      failures=0

      echo "Network Check"
      echo "────────────────────────────"

      if public_ip="$(myip 2>/dev/null)"; then
        echo "Public IP:     $public_ip"
      else
        echo "Public IP:     <unavailable>"
        failures=$((failures + 1))
      fi

      default_route="$(ip route show default 2>/dev/null | head -n 1 || true)"
      if [[ -n "$default_route" ]]; then
        echo "Default route: $default_route"
      else
        echo "Default route: <missing>"
        failures=$((failures + 1))
      fi

      egress_route="$(ip route get 1.1.1.1 2>/dev/null | head -n 1 || true)"
      if [[ -n "$egress_route" ]]; then
        echo "Egress route:  $egress_route"
      else
        echo "Egress route:  <unavailable>"
        failures=$((failures + 1))
      fi

      echo
      echo "Interfaces"
      echo "────────────────────────────"
      ip -brief address || true

      echo
      echo "DNS"
      echo "────────────────────────────"

      if [[ -r /etc/resolv.conf ]]; then
        resolver_target="$(readlink -f /etc/resolv.conf 2>/dev/null || true)"
        echo "Resolver file: ''${resolver_target:-/etc/resolv.conf}"

        dns_lines="$(
          grep -E \
            '^[[:space:]]*(nameserver|search|options)[[:space:]]' \
            /etc/resolv.conf || true
        )"

        if [[ -n "$dns_lines" ]]; then
          printf '%s\n' "$dns_lines"
        else
          echo "<no resolver entries>"
          failures=$((failures + 1))
        fi
      else
        echo "/etc/resolv.conf is not readable"
        failures=$((failures + 1))
      fi

      echo
      echo "VPN"
      echo "────────────────────────────"

      if command -v vpn >/dev/null 2>&1; then
        vpn status || echo "vpn status returned an error"
      else
        echo "vpn helper not available"
      fi

      echo
      echo "Result"
      echo "────────────────────────────"

      if (( failures == 0 )); then
        echo "Network health: PASS"
        exit 0
      fi

      echo "Network health: DEGRADED ($failures failed check(s))"
      exit 1
    '';
  };
in
{
  options.hakkabara.shell.networkTools.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install shared myip and netcheck network helpers.";
  };

  config = lib.mkIf (config.hakkabara.shell.enable && cfg.enable) {
    home.packages = [
      myIp
      netcheck
    ];
  };
}
