{ ... }:

{
  # Initial personal physical-workstation composition.
  #
  # Reuse the already-tested workstation/Niri stack and current
  # SurfVM application selection. Once Hakkapad is stable we can
  # rename/extract the remaining SurfVM-specific pieces cleanly.
  imports = [
    ./work-vm.nix
    ./personal-workstation-apps.nix
    ../../modules/home/ssh/personal-infra.nix
  ];

  hakkabara = {
    theme.matugen.enable = true;

    browsers.gecko = {
      # Work-specific proxy tooling is not part of the personal laptop.
      extensions.foxyProxy.enable = false;

      firefox = {
        profileName = "surf";
        profileDisplayName = "Surf";
        profileId = 0;
      };

      floorp = {
        profileName = "surf";
        profileDisplayName = "Surf";
        profileId = 0;
        whatsappProfile.enable = true;
      };

      bookmarks.manager = {
        enable = true;
        sourceFile = "secrets/shared/browser-bookmarks";
        documentTitle = "Personal Bookmarks";
      };
    };

    ai = {
      enable = true;

      claude = {
        enable = true;
        code.enable = true;
        omc.enable = true;
      };
    };

    # WorkVM disables all idle behavior. A laptop must not.
    desktop.dms.alwaysOn.enable = false;
  };
}
