# Shared declarative Gecko search configuration.
#
# This file is consumed by both Firefox and Floorp.
# Browser-/profile-specific search engines can be layered on top
# later without duplicating this common baseline.

# ==========================================================
# Search engines
# ==========================================================
#
# Usage examples:
#
# @ddg nixos
# @g nixos
# @yt nixos tutorial
#
# @nix firefox
# @np ripgrep
#
# @no services.openssh
# @nixopt networking.firewall
#
# @nw wireguard
#
# @aw systemd
# @arch networkmanager
#
# @gh sops-nix
# @github home-manager
#
# @sh nginx
# @shodan port:443 country:DE
#
# @wiki NixOS

{
  force = true;

  # DuckDuckGo everywhere unless an explicit alias is used.
  default = "ddg";
  privateDefault = "ddg";

  order = [
    "ddg"
    "google"
    "youtube"

    "nix-packages"
    "nixos-options"
    "nixos-wiki"
    "arch-wiki"

    "github"
    "shodan"

    "wikipedia-de"
  ];

  engines = {
    # ------------------------------------------------------
    # Built-in Firefox engines
    # ------------------------------------------------------

    ddg.metaData.alias = "@ddg";

    google.metaData.alias = "@g";

    youtube.metaData.alias = "@yt";

    "wikipedia-de".metaData.alias = "@wiki";

    # ------------------------------------------------------
    # Nix Packages
    #
    # @nix firefox
    # @np ripgrep
    # ------------------------------------------------------

    "nix-packages" = {
      name = "Nix Packages";

      urls = [
        {
          template = "https://search.nixos.org/packages";

          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@nix"
        "@np"
      ];
    };

    # ------------------------------------------------------
    # NixOS Options
    #
    # @no services.openssh
    # @nixopt networking.firewall
    # ------------------------------------------------------

    "nixos-options" = {
      name = "NixOS Options";

      urls = [
        {
          template = "https://search.nixos.org/options";

          params = [
            {
              name = "channel";
              value = "26.05";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@no"
        "@nixopt"
      ];
    };

    # ------------------------------------------------------
    # NixOS Wiki
    #
    # @nw wireguard
    # ------------------------------------------------------

    "nixos-wiki" = {
      name = "NixOS Wiki";

      urls = [
        {
          template = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
        }
      ];

      definedAliases = [
        "@nw"
      ];
    };

    # ------------------------------------------------------
    # ArchWiki
    #
    # @aw systemd
    # @arch networkmanager
    # ------------------------------------------------------

    "arch-wiki" = {
      name = "ArchWiki";

      urls = [
        {
          template = "https://wiki.archlinux.org/title/Special:Search";

          params = [
            {
              name = "search";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@aw"
        "@arch"
      ];
    };

    # ------------------------------------------------------
    # GitHub
    #
    # @gh sops-nix
    # @github home-manager
    # ------------------------------------------------------

    github = {
      name = "GitHub";

      urls = [
        {
          template = "https://github.com/search";

          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@gh"
        "@github"
      ];
    };

    # ------------------------------------------------------
    # Shodan
    #
    # @sh nginx
    # @shodan port:443 country:DE
    # ------------------------------------------------------

    shodan = {
      name = "Shodan";

      urls = [
        {
          template = "https://www.shodan.io/search";

          params = [
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@sh"
        "@shodan"
      ];
    };
  };
}
