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

    # Shared personal SSH infrastructure.
    "ssh-personal-infra" = {
      sopsFile = ../../secrets/shared/ssh-personal-infra;
      format = "binary";

      owner = "hakkabara";
      mode = "0400";
    };

    # Shared personal Homelab SMB credentials.
    "smb/homelab-main" = {
      sopsFile = ../../secrets/shared/smb.yaml;
      key = "homelab-main";

      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Shared encrypted browser bookmark source.
    "browser/bookmarks" = {
      sopsFile = ../../secrets/shared/browser-bookmarks;
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
