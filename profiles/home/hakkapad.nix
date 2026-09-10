{ lib, ... }:

{
  # Initial personal physical-workstation composition.
  #
  # Reuse the already-tested workstation/Niri stack and current
  # SurfVM application selection. Once Hakkapad is stable we can
  # rename/extract the remaining SurfVM-specific pieces cleanly.
  imports = [
    ./work-vm.nix
    ./surf-vm-apps.nix
  ];

  hakkabara = {
    theme.matugen.enable = true;

    # Work-specific proxy tooling is not part of the personal laptop.
    browsers.gecko.extensions.foxyProxy.enable = false;

    browsers.gecko.firefox = {
      profileName = "surf";
      profileDisplayName = "Surf";
      profileId = 0;
    };

    browsers.gecko.floorp = {
      profileName = "surf";
      profileDisplayName = "Surf";
      profileId = 0;
      whatsappProfile.enable = true;
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
