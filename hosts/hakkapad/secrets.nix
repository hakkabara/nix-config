{ ... }:

{
  sops.secrets = {
    # Device-specific SSH identity.
    "ssh-system-key" = {
      sopsFile = ../../secrets/hakkapad/ssh-system-key;
      format = "binary";

      owner = "hakkabara";
      mode = "0400";
    };

    # GitHub CLI authentication.
    "github/gh-token" = {
      sopsFile = ../../secrets/hakkapad/github.yaml;
      key = "gh-token";

      owner = "hakkabara";
      mode = "0400";
    };
  };
}
