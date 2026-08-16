{ ... }:

{
  sops.defaultSopsFile = ../../secrets/surf-vm.yaml;

  sops.secrets = {
    "test-secret" = { };

    "ssh-system-key" = {
      sopsFile = ../../secrets/surf-vm/ssh-system-key;
      format = "binary";
      owner = "hakkabara";
      mode = "0400";
    };
  };
}
