{
  config,
  lib,
  ...
}:

# Folders pinned in the sidebar of the GTK file chooser, which is also the
# xdg-desktop-portal FileChooser dialog (Open/Save in Firefox, Chrome, ...).
# GTK 3 and GTK 4 both read ~/.config/gtk-3.0/bookmarks.
#
# The list merges across modules, so a host profile sets its base folders and
# other configurations (e.g. nix-internal) append more:
#
#   hakkabara.desktop.fileChooserPins.pins = [
#     "/data/share/clean"
#     { path = "/data/nfs/llm"; label = "LLM"; }
#   ];
#
# The file is managed by Home Manager and therefore read-only: folders pinned
# by hand in the dialog are not saved, add them here instead.
let
  cfg = config.hakkabara.desktop.fileChooserPins;

  pinType = lib.types.coercedTo lib.types.str (path: { inherit path; }) (
    lib.types.submodule {
      options = {
        path = lib.mkOption {
          type = lib.types.str;
          description = "Absolute path of the folder to pin.";
        };

        label = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Name shown in the sidebar; the folder name if null.";
        };
      };
    }
  );

  # GTK expects file:// URIs; percent-encode what commonly occurs in paths.
  toUri = path: "file://" + lib.replaceStrings [ "%" " " "#" "?" ] [ "%25" "%20" "%23" "%3F" ] path;

  toLine = pin: toUri pin.path + lib.optionalString (pin.label != null) " ${pin.label}";
in
{
  options.hakkabara.desktop.fileChooserPins = {
    enable = lib.mkEnableOption "declarative file chooser sidebar folders";

    pins = lib.mkOption {
      type = lib.types.listOf pinType;
      default = [ ];
      description = ''
        Folders pinned in the GTK/portal file chooser, in this order. A plain
        string is a path; an attrset sets path and label.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (pin: lib.hasPrefix "/" pin.path) cfg.pins;
        message = "hakkabara.desktop.fileChooserPins.pins: every path must be absolute.";
      }
    ];

    xdg.configFile."gtk-3.0/bookmarks".text = lib.concatMapStrings (pin: toLine pin + "\n") cfg.pins;
  };
}
