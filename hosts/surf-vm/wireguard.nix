{ config, pkgs, ... }:

let
  vpn = pkgs.writeShellApplication {
    name = "vpn";

    runtimeInputs = with pkgs; [
      systemd
    ];

    text = builtins.readFile ./scripts/vpn.sh;
  };
in
{
  networking.wg-quick.interfaces = {
    "homelab-split" = {
      autostart = false;
      configFile = config.sops.secrets."wireguard/homelab-split".path;
    };

    "homelab-full" = {
      autostart = true;
      configFile = config.sops.secrets."wireguard/homelab-full".path;
    };
  };

  environment.systemPackages = [
    vpn
  ];
}
