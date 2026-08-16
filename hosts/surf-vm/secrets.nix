{ ... }:

{
  sops.defaultSopsFile = ../../secrets/surf-vm.yaml;

  sops.secrets."test-secret" = { };
}
