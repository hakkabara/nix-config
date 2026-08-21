{ config, lib, ... }:

let
  cfg = config.hakkabara.browsers.gecko;

  shared = import ./shared.nix {
    inherit lib cfg;
  };

  bookmarks = import ./bookmarks.nix;
in
{
  programs.floorp = {
    enable = cfg.floorp.enable;

    # Firefox-compatible baseline shared with Firefox.
    policies = lib.recursiveUpdate shared.policies bookmarks.policies;

    # Floorp keeps its own profile state below ~/.floorp.
    profiles.surf = {
      id = 0;
      name = "Surf";
      isDefault = true;

      settings = shared.profileSettings // bookmarks.profileSettings;

      search = import ./search.nix;
    };
  };
}
