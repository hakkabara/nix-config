{ ... }:

{
  imports = [
    ../../modules/nixos/networking/wifi-sops.nix
  ];

  hakkabara.networking.wifiSops = {
    enable = true;

    sopsFile = ../../secrets/hakkapad/wifi.yaml;

    networks = [
      "wifi1"
      "wifi2"
      "wifi3"
      "wifi4"
    ];
  };
}
