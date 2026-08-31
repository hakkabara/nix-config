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
  };
}
