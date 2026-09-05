{ config, ... }:

{
  sops.secrets = {
    "github/gh-token" = {
      sopsFile = ../../secrets/work-vm/github.yaml;
      key = "gh-token";
      owner = "mko";
      mode = "0400";
    };

    "github/ssh-key" = {
      sopsFile = ../../secrets/work-vm/github-ssh-key;
      format = "binary";
      owner = "mko";
      mode = "0400";
    };

    "ssh/work-config" = {
      sopsFile = ../../secrets/work-vm/ssh.yaml;
      key = "ssh-config";
      owner = "mko";
      group = "users";
      mode = "0400";
    };

    "ssh/customer-template" = {
      sopsFile = ../../secrets/work-vm/ssh.yaml;
      key = "customer-template";
      owner = "mko";
      group = "users";
      mode = "0400";
    };

    "docker/bloodhound-ce.env" = {
      sopsFile = ../../secrets/work-vm/docker.yaml;
      key = "bloodhound-ce-env";
      owner = "mko";
      mode = "0400";
    };

    "docker/arkime.env" = {
      sopsFile = ../../secrets/work-vm/docker.yaml;
      key = "arkime-env";
      owner = "mko";
      mode = "0400";
    };

    "docker/bloodhound-legacy.env" = {
      sopsFile = ../../secrets/work-vm/docker.yaml;
      key = "bloodhound-legacy-env";
      owner = "mko";
      mode = "0400";
    };

    "network/dnsmasq-private.conf" = {
      sopsFile = ../../secrets/work-vm/dns.yaml;
      key = "dnsmasq-private";
      owner = "dnsmasq";
      group = "dnsmasq";
      mode = "0400";
    };
  };

  hakkabara.networking.splitDns = {
    enable = true;
    privateConfigFile = config.sops.secrets."network/dnsmasq-private.conf".path;
  };
}
