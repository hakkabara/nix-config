{ ... }:

{
  # ============================================================
  # SOPS
  # ============================================================

  sops = {
    # Default SOPS file for secrets which do not specify their
    # own sopsFile explicitly.
    defaultSopsFile = ../../secrets/surf-vm.yaml;

    # ==========================================================
    # Runtime secrets
    # ==========================================================

    secrets = {
      # --------------------------------------------------------
      # SSH
      # --------------------------------------------------------

      "ssh-personal-infra" = {
        sopsFile = ../../secrets/shared/ssh-personal-infra;
        format = "binary";

        owner = "hakkabara";
        mode = "0400";
      };

      "ssh-system-key" = {
        sopsFile = ../../secrets/surf-vm/ssh-system-key;
        format = "binary";

        owner = "hakkabara";
        mode = "0400";
      };

      # --------------------------------------------------------
      # GitHub CLI
      # --------------------------------------------------------

      "github/gh-token" = {
        sopsFile = ../../secrets/surf-vm/github.yaml;
        key = "gh-token";

        owner = "hakkabara";
        mode = "0400";
      };

      # --------------------------------------------------------
      # WireGuard
      # --------------------------------------------------------

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

      "wireguard/rvpn" = {
        sopsFile = ../../secrets/surf-vm/rvpn.conf;
        format = "binary";

        owner = "root";
        group = "root";
        mode = "0400";
      };

      # --------------------------------------------------------
      # SMB
      # --------------------------------------------------------

      "smb/homelab-main" = {
        sopsFile = ../../secrets/surf-vm/smb.yaml;
        key = "homelab-main";

        owner = "root";
        group = "root";
        mode = "0400";
      };

      # --------------------------------------------------------
      # Browser bookmarks
      # --------------------------------------------------------

      "browser/bookmarks" = {
        sopsFile = ../../secrets/surf-vm/browser-bookmarks;
        format = "binary";

        owner = "hakkabara";
        mode = "0400";
      };

      # --------------------------------------------------------
      # Pi-hole
      # --------------------------------------------------------

      "pihole/deacpi01/url" = {
        key = "api/pihole/deacpi01/url";

        owner = "hakkabara";
        mode = "0400";
      };

      "pihole/deacpi01/token" = {
        key = "api/pihole/deacpi01/token";

        owner = "hakkabara";
        mode = "0400";
      };

      "pihole/derbpi01/url" = {
        key = "api/pihole/derbpi01/url";

        owner = "hakkabara";
        mode = "0400";
      };

      "pihole/derbpi01/token" = {
        key = "api/pihole/derbpi01/token";

        owner = "hakkabara";
        mode = "0400";
      };

    };

  };

}
