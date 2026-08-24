{ config, pkgs, ... }:

let
  homelabVpnManager = pkgs.writeShellApplication {
    name = "homelab-vpn-manager";

    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      gnugrep
      iproute2
      iputils
      systemd
      wireguard-tools
    ];

    text = builtins.readFile ./scripts/vpn-manager.sh;
  };

  vpn = pkgs.writeShellApplication {
    name = "vpn";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.iproute2
      pkgs.systemd
      homelabVpnManager
    ];

    text = builtins.readFile ./scripts/vpn.sh;
  };
in
{
  networking.wg-quick.interfaces = {
    "homelab-split" = {
      # The persistent VPN manager owns all automatic activation.
      autostart = false;
      configFile = config.sops.secrets."wireguard/homelab-split".path;
    };

    "homelab-full" = {
      # Do not let wg-quick override an explicit `vpn off`.
      autostart = false;
      configFile = config.sops.secrets."wireguard/homelab-full".path;
    };

    "airvpn" = {
      # RVPN is controlled by the persistent VPN manager.
      autostart = false;
      configFile = config.sops.secrets."wireguard/airvpn".path;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/homelab-vpn 0755 root root -"
  ];

  systemd.services.homelab-vpn-manager = {
    description = "SurfVM WireGuard VPN mode manager";

    wants = [
      "network-online.target"
    ];

    after = [
      "network-online.target"
    ];

    wantedBy = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "simple";

      ExecStart =
        "${homelabVpnManager}/bin/homelab-vpn-manager run";

      Restart = "always";
      RestartSec = "3s";
    };
  };

  environment.systemPackages = [
    vpn
    homelabVpnManager
  ];
}
