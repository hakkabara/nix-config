{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.theme.matugen;

  wallpaperDir = "${config.xdg.dataHome}/wallpapers/nix-config";
  stateDir = "${config.xdg.stateHome}/hakkabara-rice";

  rice = pkgs.writeShellApplication {
    name = "rice";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.file
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.matugen
      pkgs.kdePackages.plasma-workspace
    ];

    text = ''
            set -euo pipefail

            wallpaper_dir=${lib.escapeShellArg wallpaperDir}
            state_dir=${lib.escapeShellArg stateDir}

            current_file="$state_dir/current-wallpaper"
            mode_file="$state_dir/mode"

            mkdir -p "$state_dir"

            usage() {
              cat <<'USAGE'
      Usage:
        rice list
        rice wallpaper <name-or-path>
        rice next
        rice previous
        rice random
        rice regenerate
        rice color <#RRGGBB>
        rice tokyo
        rice status

      Commands:
        list
            List wallpapers managed by Nix.

        wallpaper <name-or-path>
            Set Plasma wallpaper and generate a matching Matugen palette.

        next / previous
            Move through the Git-managed wallpaper collection.

        random
            Pick a random managed wallpaper.

        regenerate
            Regenerate Matugen colors from the current wallpaper.

        color <#RRGGBB>
            Generate colors from a fixed seed without changing wallpaper.

        tokyo
            Restore the Tokyo Night blue Matugen baseline.

        status
            Show current rice state.
      USAGE
            }

            list_paths() {
              if [[ ! -d "$wallpaper_dir" ]]; then
                return 0
              fi

              find -L "$wallpaper_dir" \
                -maxdepth 1 \
                -type f \
                \( \
                  -iname '*.png' \
                  -o -iname '*.jpg' \
                  -o -iname '*.jpeg' \
                  -o -iname '*.webp' \
                  -o -iname '*.avif' \
                \) \
                -print0 |
                sort -z
            }

            list_names() {
              while IFS= read -r -d "" image; do
                basename "$image"
              done < <(list_paths)
            }

            resolve_image() {
              local input="$1"
              local candidate

              if [[ -f "$input" ]]; then
                candidate="$(realpath "$input")"
              elif [[ -f "$wallpaper_dir/$input" ]]; then
                candidate="$(realpath "$wallpaper_dir/$input")"
              else
                printf 'ERROR: wallpaper not found: %s\n' "$input" >&2
                printf '\nAvailable wallpapers:\n' >&2
                list_names >&2 || true
                return 1
              fi

              local mime
              mime="$(file --brief --mime-type "$candidate")"

              if [[ "$mime" != image/* ]]; then
                printf 'ERROR: not an image: %s (%s)\n' \
                  "$candidate" "$mime" >&2
                return 1
              fi

              printf '%s\n' "$candidate"
            }

            remember_wallpaper() {
              local image="$1"

              printf '%s\n' "$image" > "$current_file"
              printf '%s\n' "wallpaper" > "$mode_file"
            }

            apply_wallpaper() {
              local image
              image="$(resolve_image "$1")"

              printf 'Wallpaper: %s\n' "$image"

              # KDE owns wallpaper application.
              plasma-apply-wallpaperimage "$image"

              # Matugen owns dynamic application colors.
              matugen image "$image" -m dark --source-color-index 0

              remember_wallpaper "$image"

              printf 'Palette:   Matugen dark\n'
            }

            current_wallpaper() {
              if [[ -s "$current_file" ]]; then
                cat "$current_file"
              fi
            }

            cycle_wallpaper() {
              local direction="$1"

              mapfile -d "" -t images < <(list_paths)

              if (( ''${#images[@]} == 0 )); then
                echo "ERROR: no wallpapers found in:"
                echo "  $wallpaper_dir"
                exit 1
              fi

              local current=""
              if [[ -s "$current_file" ]]; then
                current="$(cat "$current_file")"
              fi

              local index=-1
              local i

              for i in "''${!images[@]}"; do
                if [[ "$(realpath "''${images[$i]}")" == "$current" ]]; then
                  index="$i"
                  break
                fi
              done

              if [[ "$direction" == "next" ]]; then
                if (( index < 0 )); then
                  index=0
                else
                  index=$(( (index + 1) % ''${#images[@]} ))
                fi
              else
                if (( index < 0 )); then
                  index=$(( ''${#images[@]} - 1 ))
                else
                  index=$(( (index - 1 + ''${#images[@]}) % ''${#images[@]} ))
                fi
              fi

              apply_wallpaper "''${images[$index]}"
            }

            case "''${1:-}" in
              list)
                list_names
                ;;

              wallpaper)
                if (( $# != 2 )); then
                  usage
                  exit 2
                fi

                apply_wallpaper "$2"
                ;;

              next)
                cycle_wallpaper next
                ;;

              previous|prev)
                cycle_wallpaper previous
                ;;

              random)
                mapfile -d "" -t images < <(list_paths)

                if (( ''${#images[@]} == 0 )); then
                  echo "ERROR: no wallpapers available."
                  exit 1
                fi

                selected="$(
                  printf '%s\n' "''${images[@]}" |
                    shuf -n 1
                )"

                apply_wallpaper "$selected"
                ;;

              regenerate)
                image="$(current_wallpaper)"

                if [[ -z "$image" || ! -f "$image" ]]; then
                  echo "ERROR: no valid current wallpaper stored."
                  exit 1
                fi

                matugen image "$image" -m dark --source-color-index 0

                echo "Regenerated:"
                echo "  $image"
                ;;

              color)
                if (( $# != 2 )); then
                  usage
                  exit 2
                fi

                matugen color hex "$2" -m dark

                printf '%s\n' "color:$2" > "$mode_file"

                echo "Generated Matugen palette from $2"
                ;;

              tokyo)
                matugen color hex '#7aa2f7' -m dark

                printf '%s\n' "tokyo" > "$mode_file"

                echo "Restored Tokyo Night Matugen baseline."
                ;;

              status)
                echo "Wallpaper directory:"
                echo "  $wallpaper_dir"
                echo

                if [[ -s "$mode_file" ]]; then
                  echo "Mode:"
                  echo "  $(cat "$mode_file")"
                else
                  echo "Mode:"
                  echo "  unknown"
                fi

                echo

                if [[ -s "$current_file" ]]; then
                  echo "Current wallpaper:"
                  echo "  $(cat "$current_file")"
                else
                  echo "Current wallpaper:"
                  echo "  none selected through rice yet"
                fi

                echo

                count="$(
                  list_names |
                    awk 'END { print NR + 0 }'
                )"

                echo "Managed wallpapers:"
                echo "  $count"
                ;;

              ""|-h|--help|help)
                usage
                ;;

              *)
                echo "ERROR: unknown command: $1" >&2
                echo >&2
                usage >&2
                exit 2
                ;;
            esac
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      rice
    ];

    # Wallpapers live in the Git repository and are deployed by Home Manager.
    #
    # recursive=true gives every individual wallpaper its own store-backed
    # symlink. realpath in the rice wrapper therefore changes when the actual
    # image changes, which also avoids stale Plasma wallpaper cache paths.
    xdg.dataFile."wallpapers/nix-config" = {
      source = ../../../assets/wallpapers;
      recursive = true;
    };
  };
}
