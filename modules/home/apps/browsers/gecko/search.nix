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
#
# @hm programs.kitty
# @noogle mapAttrs
# @nixpr kitty
#
# @vt 44d88612fea8a8f36de82e1278abb02f
# @us example.com
# @aip 198.51.100.7
# @crt example.com
# @cve CVE-2024-3094
# @mb emotet
# @gn 198.51.100.7
# @edb openssl
#
# @velo Windows.KapeFiles.Targets
# @vr hunt

# release: NixOS release of the system ("26.05"), so the option searches
# follow the flake's nixpkgs instead of a hard-coded channel.
{ release }:

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
    "home-manager-options"
    "noogle"
    "nixos-wiki"
    "arch-wiki"

    "github"
    "nixpkgs-prs"

    "shodan"
    "virustotal"
    "urlscan"
    "abuseipdb"
    "crtsh"
    "cve"
    "malwarebazaar"
    "greynoise"
    "exploit-db"

    "velociraptor-docs"

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
              value = release;
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

    # ------------------------------------------------------
    # Home Manager options
    #
    # @hm programs.kitty
    # ------------------------------------------------------

    "home-manager-options" = {
      name = "Home Manager Options";

      urls = [
        {
          template = "https://home-manager-options.extranix.com/";

          params = [
            {
              name = "query";
              value = "{searchTerms}";
            }
            {
              name = "release";
              value = "release-${release}";
            }
          ];
        }
      ];

      definedAliases = [
        "@hm"
      ];
    };

    # ------------------------------------------------------
    # Noogle (Nix function search)
    #
    # @noogle mapAttrs
    # @ng mkIf
    # ------------------------------------------------------

    noogle = {
      name = "Noogle";

      urls = [
        {
          template = "https://noogle.dev/q/";

          params = [
            {
              name = "term";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@noogle"
        "@ng"
      ];
    };

    # ------------------------------------------------------
    # nixpkgs pull requests
    #
    # @nixpr kitty
    # ------------------------------------------------------

    "nixpkgs-prs" = {
      name = "nixpkgs Pull Requests";

      urls = [
        {
          template = "https://github.com/NixOS/nixpkgs/pulls";

          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@nixpr"
      ];
    };

    # ------------------------------------------------------
    # Threat intelligence and vulnerability lookups
    #
    # The term is part of the path or fragment for some of
    # these, so they use an inline {searchTerms} template.
    # ------------------------------------------------------

    virustotal = {
      name = "VirusTotal";
      urls = [ { template = "https://www.virustotal.com/gui/search/{searchTerms}"; } ];
      definedAliases = [ "@vt" ];
    };

    urlscan = {
      name = "urlscan.io";
      urls = [ { template = "https://urlscan.io/search/#{searchTerms}"; } ];
      definedAliases = [
        "@us"
        "@urlscan"
      ];
    };

    abuseipdb = {
      name = "AbuseIPDB";
      urls = [ { template = "https://www.abuseipdb.com/check/{searchTerms}"; } ];
      definedAliases = [
        "@aip"
        "@abuse"
      ];
    };

    crtsh = {
      name = "crt.sh";

      urls = [
        {
          template = "https://crt.sh/";

          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [ "@crt" ];
    };

    cve = {
      name = "CVE";

      urls = [
        {
          template = "https://www.cve.org/CVERecord/SearchResults";

          params = [
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [ "@cve" ];
    };

    malwarebazaar = {
      name = "MalwareBazaar";

      urls = [
        {
          template = "https://bazaar.abuse.ch/browse.php";

          params = [
            {
              name = "search";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@mb"
        "@bazaar"
      ];
    };

    greynoise = {
      name = "GreyNoise";
      urls = [ { template = "https://viz.greynoise.io/query/{searchTerms}"; } ];
      definedAliases = [
        "@gn"
        "@greynoise"
      ];
    };

    "exploit-db" = {
      name = "Exploit-DB";

      urls = [
        {
          template = "https://www.exploit-db.com/search";

          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [ "@edb" ];
    };

    # ------------------------------------------------------
    # Velociraptor documentation (docs, artifact reference, VQL)
    #
    # @velo Windows.KapeFiles.Targets
    # @vr hunt
    # ------------------------------------------------------

    "velociraptor-docs" = {
      name = "Velociraptor Docs";

      urls = [
        {
          template = "https://docs.velociraptor.app/search/";

          params = [
            {
              name = "q";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      definedAliases = [
        "@velo"
        "@vr"
      ];
    };
  };
}
