{ ... }:

{
  sops.defaultSopsFile = ../../secrets/surf-vm.yaml;

  sops.secrets = {
    "test-secret" = { };

    "ssh-personal-infra" = {
      sopsFile = ../../secrets/shared/ssh-personal-infra;
      format = "binary";
      owner = "hakkabara";
      mode = "0400";
    };

    "wireguard/homelab-split" = {
      sopsFile = ../../secrets/surf-vm/wireguard.yaml;
      key = "homelab-split";

      owner = "root";
      group = "root";
      mode = "0400";

      restartUnits = [
        "wg-quick-homelab-split.service"
      ];
    };
    "wireguard/homelab-full" = {
      sopsFile = ../../secrets/surf-vm/wireguard.yaml;
      key = "homelab-full";

      owner = "root";
      group = "root";
      mode = "0400";
    };
    "ssh-system-key" = {
      sopsFile = ../../secrets/surf-vm/ssh-system-key;
      format = "binary";
      owner = "hakkabara";
      mode = "0400";
    };
  };
}
