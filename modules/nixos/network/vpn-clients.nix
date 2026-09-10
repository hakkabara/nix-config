{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.network.vpnClients;
in
{
  options.hakkabara.network.vpnClients = {
    enable = lib.mkEnableOption "reusable VPN client tooling";

    openvpn = {
      enable = lib.mkEnableOption "OpenVPN client";

      networkManager.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NetworkManager support for OpenVPN.";
      };
    };

    wireguard.enable = lib.mkEnableOption "WireGuard client tools";

    fortinet = {
      enable = lib.mkEnableOption "OpenFortiVPN client";

      networkManager.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NetworkManager support for Fortinet SSL VPN.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals cfg.openvpn.enable [
        pkgs.openvpn
      ]
      ++ lib.optionals cfg.wireguard.enable [
        pkgs.wireguard-tools
      ]
      ++ lib.optionals cfg.fortinet.enable [
        pkgs.openfortivpn
      ];

    networking.networkmanager.plugins =
      lib.optionals (cfg.openvpn.enable && cfg.openvpn.networkManager.enable) [
        pkgs.networkmanager-openvpn
      ]
      ++ lib.optionals (cfg.fortinet.enable && cfg.fortinet.networkManager.enable) [
        pkgs.networkmanager-fortisslvpn
      ];
  };
}
