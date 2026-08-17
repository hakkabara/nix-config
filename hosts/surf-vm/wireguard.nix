{ config, ... }:

{
  networking.wg-quick.interfaces."homelab-split" = {
    autostart = true;
    configFile = config.sops.secrets."wireguard/homelab-split".path;
  };
}
