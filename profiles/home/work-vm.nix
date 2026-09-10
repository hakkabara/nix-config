{
  lib,
  ...
}:

{
  imports = [
    ./workstation-base.nix
    ./niri-workstation.nix
  ];

  hakkabara = {
    apps = {
      keepassxc.enable = lib.mkDefault true;
      copyq.enable = lib.mkDefault true;
      obsidian.enable = lib.mkDefault true;
      signal.enable = lib.mkDefault true;
    };

    browsers = {
      gecko = {
        extensions.foxyProxy.enable = lib.mkDefault true;

        firefox = {
          enable = lib.mkDefault true;
          profileName = lib.mkDefault "work";
          profileDisplayName = lib.mkDefault "Work";
          profileId = lib.mkDefault 0;
        };

        floorp = {
          enable = lib.mkDefault true;
          profileName = lib.mkDefault "work";
          profileDisplayName = lib.mkDefault "Work";
          profileId = lib.mkDefault 0;
          whatsappProfile.enable = lib.mkDefault false;

          graphics.xwaylandGlx.enable = lib.mkDefault true;
        };
      };

      chromium = {
        chromium.enable = lib.mkDefault true;
        googleChrome.enable = lib.mkDefault true;
        vivaldi.enable = lib.mkDefault true;
      };
    };
  };
}
