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
    # --------------------------------------------------------
    # Shared personal Pi-hole API
    # --------------------------------------------------------

    "pihole/deacpi01/url" = {
      sopsFile = ../../secrets/shared/pihole.yaml;
      key = "api/pihole/deacpi01/url";
      owner = "hakkabara";
      mode = "0400";
    };

    "pihole/deacpi01/token" = {
      sopsFile = ../../secrets/shared/pihole.yaml;
      key = "api/pihole/deacpi01/token";
      owner = "hakkabara";
      mode = "0400";
    };

    "pihole/derbpi01/url" = {
      sopsFile = ../../secrets/shared/pihole.yaml;
      key = "api/pihole/derbpi01/url";
      owner = "hakkabara";
      mode = "0400";
    };

    "pihole/derbpi01/token" = {
      sopsFile = ../../secrets/shared/pihole.yaml;
      key = "api/pihole/derbpi01/token";
      owner = "hakkabara";
      mode = "0400";
    };

  };
}
