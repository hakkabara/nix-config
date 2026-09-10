{ ... }:

{
  # Shared private workstation layer.
  #
  # Imported by trusted personal machines:
  #   - SurfVM
  #   - Hakkapad
  #
  # Desktop/compositor and physical/VM hardware intentionally live elsewhere.
  imports = [
    ./workstation-base.nix
    ./personal-workstation-apps.nix
    ../../modules/home/ssh/personal-infra.nix
    ../../modules/home/helpers
  ];

  hakkabara = {
    theme.matugen.enable = true;

    ai = {
      enable = true;

      claude = {
        enable = true;
        code.enable = true;
        omc.enable = true;
      };
    };

    browsers = {
      gecko = {
        firefox = {
          enable = true;
          profileName = "surf";
          profileDisplayName = "Surf";
          profileId = 0;
        };

        floorp = {
          enable = true;
          profileName = "surf";
          profileDisplayName = "Surf";
          profileId = 0;
          whatsappProfile.enable = true;
        };

        # Keep only dynamic browsing state in Firefox Sync.
        # Declarative bookmarks/extensions/settings remain managed by Nix.
        sync.firefox = {
          enable = true;
          locked = true;

          history = true;
          openTabs = true;

          bookmarks = false;
          passwords = false;
          addons = false;
          settings = false;
          addresses = false;
          paymentMethods = false;
        };

        privacy = {
          antiClutter.enable = true;
          remoteSearchSuggestions.enable = false;

          cookies = {
            common = {
              clearOnShutdown = true;

              # Existing personal persistence baseline.
              # The mechanism is shared; the concrete private whitelist
              # can later move behind the private/SOPS configuration layer.
              persistentOrigins = [
                "https://web.whatsapp.com"

                "https://chatgpt.com"
                "https://auth.openai.com"

                "https://gemini.google.com"

                "https://claude.ai"
              ];
            };

            firefox.mode = "inherit";
            floorp.mode = "inherit";
          };
        };

        bookmarks.manager = {
          enable = true;
          sourceFile = "secrets/shared/browser-bookmarks";
          documentTitle = "Personal Bookmarks";
        };

        extensions = {
          violentmonkey = {
            enable = true;

            firefox.runtimeBlockedHosts = [
              "*://*"
            ];
          };

          bitwarden.enable = true;
          multiAccountContainers.enable = true;

          sponsorBlock = {
            enable = true;

            firefox = {
              runtimeBlockedHosts = [
                "*://*"
              ];

              runtimeAllowedHosts = [
                "https://*.youtube.com"
                "https://www.youtube-nocookie.com"
                "https://sponsor.ajay.app"
              ];
            };
          };

          enhancerForYouTube = {
            enable = true;

            firefox = {
              runtimeBlockedHosts = [
                "*://*"
              ];

              runtimeAllowedHosts = [
                "https://www.youtube.com"
              ];
            };
          };

          twitchAdSolutions.enable = true;
        };
      };

      chromium = {
        chromium.enable = true;
        vivaldi.enable = true;
      };
    };
  };
}
