{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
  };
in
{
  programs.floorp = {
    enable = cfg.floorp.enable;

    # Firefox-compatible baseline shared with Firefox.
    inherit (shared) policies;

    # Floorp keeps its own profile state below ~/.floorp.
    profiles.surf = {
      id = 0;
      name = "Surf";
      isDefault = true;

      settings = shared.profileSettings;
    };
  };
}
