{ ... }:

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
  };
}
