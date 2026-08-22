{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.browsers.gecko;

  jsonFormat = pkgs.formats.json { };

  baseline = import ./dark-reader-baseline.nix;

  renderedSettings = jsonFormat.generate "dark-reader-settings.json" baseline;

  darkReaderSettings = pkgs.writeShellApplication {
    name = "darkreader-settings";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
    ];

    text = ''
      managed="${config.xdg.configHome}/dark-reader/settings.json"

      usage() {
        cat <<'EOF'
Dark Reader declarative settings helper

Usage:
  darkreader-settings path
  darkreader-settings show
  darkreader-settings check
  darkreader-settings copy
  darkreader-settings compare <export.json>

Commands:
  path
      Print the Home Manager managed settings path.

  show
      Pretty-print the declarative settings.

  check
      Validate that the managed file contains valid JSON.

  copy
      Copy the declarative settings to:
      ~/Downloads/Dark-Reader-Nix.json

      Import that file in Dark Reader:
      Settings -> Manage settings -> Import settings

  compare <export.json>
      Compare a fresh Dark Reader export with the declarative baseline.
EOF
      }

      case "''${1:-}" in
        path)
          printf '%s\n' "$managed"
          ;;

        show)
          jq . "$managed"
          ;;

        check)
          jq empty "$managed"
          echo "OK: Dark Reader declarative settings are valid JSON."
          ;;

        copy)
          destination="$HOME/Downloads/Dark-Reader-Nix.json"

          mkdir -p "$HOME/Downloads"
          install -m 600 "$managed" "$destination"

          echo "Created:"
          echo "  $destination"
          echo
          echo "Import in Dark Reader:"
          echo "  Settings -> Manage settings -> Import settings"
          ;;

        compare)
          export_file="''${2:-}"

          if [ -z "$export_file" ] || [ ! -f "$export_file" ]; then
            echo "ERROR: provide a Dark Reader JSON export" >&2
            echo "Example:" >&2
            echo "  darkreader-settings compare ~/Downloads/Dark-Reader-Settings.json" >&2
            exit 1
          fi

          tmp_managed="$(mktemp)"
          tmp_export="$(mktemp)"

          trap 'rm -f "$tmp_managed" "$tmp_export"' EXIT

          jq -S . "$managed" > "$tmp_managed"
          jq -S . "$export_file" > "$tmp_export"

          if diff -u "$tmp_managed" "$tmp_export"; then
            echo
            echo "MATCH: export equals declarative baseline."
          else
            echo
            echo "DIFFERENT: review the diff above."
            exit 2
          fi
          ;;

        help|-h|--help|"")
          usage
          ;;

        *)
          echo "ERROR: unknown command: $1" >&2
          echo >&2
          usage >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  config = lib.mkIf (
    cfg.extensions.darkReader.enable
    && (cfg.firefox.enable || cfg.floorp.enable)
  ) {
    # This is deliberately NOT browser-extension-data/storage.js.
    #
    # Home Manager's extension.settings mechanism currently makes
    # extension storage read-only and can destroy persistent runtime
    # state. Keep this as a canonical import source instead.
    xdg.configFile."dark-reader/settings.json".source = renderedSettings;

    home.packages = [
      darkReaderSettings
    ];
  };
}
