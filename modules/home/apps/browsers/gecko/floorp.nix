{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  extensionSettings = import ./extensions.nix {
    inherit lib;
    cfg = cfg.extensions;
  };
in
{
  programs.floorp = {
    enable = cfg.floorp.enable;

    policies = {
      # Floorp itself is updated through Nix.
      DisableAppUpdate = true;

      # Browser extensions may continue updating through AMO.
      ExtensionUpdate = true;

      # The system-wide default browser will be managed through XDG later.
      DontCheckDefaultBrowser = true;

      # Reuse the same declarative Gecko extension selection as Firefox.
      ExtensionSettings = extensionSettings;
    };

    # Floorp keeps its own profile state below ~/.floorp.
    profiles.surf = {
      id = 0;
      name = "Surf";
      isDefault = true;
    };
  };
}
