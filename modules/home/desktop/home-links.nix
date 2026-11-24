{
  config,
  lib,
  ...
}:

# Links in the home directory to places outside it, for example ~/data to
# /data, so file managers and dialogs reach them from home:
#
#   hakkabara.desktop.homeLinks.data = "/data";
#
# The target is not managed and does not have to exist at build time.
let
  cfg = config.hakkabara.desktop.homeLinks;
in
{
  options.hakkabara.desktop.homeLinks = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = {
      data = "/data";
    };
    description = "Symlinks in the home directory: name -> absolute target.";
  };

  config.home.file = lib.mapAttrs (_: target: {
    source = config.lib.file.mkOutOfStoreSymlink target;
  }) cfg;
}
