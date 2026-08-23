{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.theme.matugen;

  cacheDir = "${config.xdg.cacheHome}/matugen";

  riceColors = pkgs.writeShellApplication {
    name = "rice-colors";

    runtimeInputs = [
      pkgs.matugen
      pkgs.coreutils
    ];

    text = ''
            set -euo pipefail

            usage() {
              cat <<'USAGE'
      Usage:
        rice-colors image /path/to/wallpaper
        rice-colors color '#7aa2f7'

      This generates a dark Matugen palette.

      It currently updates:
        - Kitty
        - btop
        - Yazi
        - VS Code palette cache

      It does not change the Plasma wallpaper yet.
      USAGE
            }

            if (( $# != 2 )); then
              usage
              exit 2
            fi

            case "$1" in
              image)
                image="$(realpath "$2")"

                if [[ ! -f "$image" ]]; then
                  echo "ERROR: image does not exist: $image" >&2
                  exit 1
                fi

                exec matugen image "$image" -m dark
                ;;

              color)
                exec matugen color hex "$2" -m dark
                ;;

              *)
                usage
                exit 2
                ;;
            esac
    '';
  };
in
{
  options.hakkabara.theme.matugen.enable = lib.mkEnableOption "dynamic Matugen color generation";

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.matugen
      riceColors
    ];

    # -------------------------------------------------------------------------
    # Matugen
    # -------------------------------------------------------------------------

    xdg.configFile = {
      "matugen/config.toml".text = ''
        # Matugen 4.x requires the top-level config table even when we
        # currently rely on its defaults.
        [config]

        [templates.kitty]
        input_path = '${config.xdg.configHome}/matugen/templates/kitty.conf'
        output_path = '${cacheDir}/kitty.conf'
        post_hook = '${pkgs.procps}/bin/pkill -USR1 kitty || true'

        [templates.btop]
        input_path = '${config.xdg.configHome}/matugen/templates/btop.theme'
        output_path = '${cacheDir}/btop.theme'
        post_hook = '${pkgs.procps}/bin/pkill -USR2 btop || true'

        [templates.yazi]
        input_path = '${config.xdg.configHome}/matugen/templates/yazi.toml'
        output_path = '${cacheDir}/yazi.toml'

        # Prepared for the later declarative VS Code block.
        [templates.vscode-raw]
        input_path = '${config.xdg.configHome}/matugen/templates/vscode-colors'
        output_path = '${cacheDir}/vscode-colors'

        [templates.vscode-json]
        input_path = '${config.xdg.configHome}/matugen/templates/vscode-colors.json'
        output_path = '${cacheDir}/vscode-colors.json'
      '';

      # -----------------------------------------------------------------------
      # Kitty
      # -----------------------------------------------------------------------

      "matugen/templates/kitty.conf".text = ''
        background {{ colors.surface.default.hex }}
        foreground {{ colors.on_surface.default.hex }}

        cursor {{ colors.primary.default.hex }}
        cursor_text_color {{ colors.on_primary.default.hex }}

        selection_background {{ colors.secondary_container.default.hex }}
        selection_foreground {{ colors.on_secondary_container.default.hex }}

        url_color {{ colors.tertiary.default.hex }}

        color0  {{ colors.surface.default.hex }}
        color1  {{ colors.error.default.hex }}
        color2  {{ colors.tertiary.default.hex }}
        color3  {{ colors.secondary.default.hex }}
        color4  {{ colors.primary.default.hex }}
        color5  {{ colors.tertiary_fixed_dim.default.hex }}
        color6  {{ colors.secondary_fixed_dim.default.hex }}
        color7  {{ colors.on_surface.default.hex }}

        color8  {{ colors.surface_variant.default.hex }}
        color9  {{ colors.error_container.default.hex }}
        color10 {{ colors.tertiary_container.default.hex }}
        color11 {{ colors.secondary_container.default.hex }}
        color12 {{ colors.primary_container.default.hex }}
        color13 {{ colors.on_secondary_fixed_variant.default.hex }}
        color14 {{ colors.on_tertiary_fixed_variant.default.hex }}
        color15 {{ colors.on_surface_variant.default.hex }}
      '';

      # -----------------------------------------------------------------------
      # btop
      # -----------------------------------------------------------------------

      "matugen/templates/btop.theme".text = ''
        theme[main_bg]="{{ colors.surface.default.hex }}"
        theme[main_fg]="{{ colors.on_surface.default.hex }}"

        theme[title]="{{ colors.primary.default.hex }}"
        theme[hi_fg]="{{ colors.tertiary.default.hex }}"

        theme[selected_bg]="{{ colors.primary_container.default.hex }}"
        theme[selected_fg]="{{ colors.on_primary_container.default.hex }}"

        theme[inactive_fg]="{{ colors.outline.default.hex }}"
        theme[graph_text]="{{ colors.on_surface_variant.default.hex }}"
        theme[meter_bg]="{{ colors.surface_container_highest.default.hex }}"

        theme[proc_misc]="{{ colors.secondary.default.hex }}"

        theme[cpu_box]="{{ colors.primary.default.hex }}"
        theme[mem_box]="{{ colors.secondary.default.hex }}"
        theme[net_box]="{{ colors.tertiary.default.hex }}"
        theme[proc_box]="{{ colors.primary.default.hex }}"
        theme[div_line]="{{ colors.outline_variant.default.hex }}"

        theme[temp_start]="{{ colors.tertiary.default.hex }}"
        theme[temp_mid]="{{ colors.secondary.default.hex }}"
        theme[temp_end]="{{ colors.error.default.hex }}"

        theme[cpu_start]="{{ colors.primary.default.hex }}"
        theme[cpu_mid]="{{ colors.secondary.default.hex }}"
        theme[cpu_end]="{{ colors.tertiary.default.hex }}"

        theme[free_start]="{{ colors.tertiary.default.hex }}"
        theme[free_mid]="{{ colors.secondary.default.hex }}"
        theme[free_end]="{{ colors.primary.default.hex }}"

        theme[cached_start]="{{ colors.secondary_container.default.hex }}"
        theme[cached_mid]="{{ colors.secondary.default.hex }}"
        theme[cached_end]="{{ colors.primary.default.hex }}"

        theme[available_start]="{{ colors.primary_container.default.hex }}"
        theme[available_mid]="{{ colors.primary.default.hex }}"
        theme[available_end]="{{ colors.tertiary.default.hex }}"

        theme[used_start]="{{ colors.primary.default.hex }}"
        theme[used_mid]="{{ colors.tertiary.default.hex }}"
        theme[used_end]="{{ colors.error.default.hex }}"

        theme[download_start]="{{ colors.primary.default.hex }}"
        theme[download_mid]="{{ colors.secondary.default.hex }}"
        theme[download_end]="{{ colors.tertiary.default.hex }}"

        theme[upload_start]="{{ colors.tertiary.default.hex }}"
        theme[upload_mid]="{{ colors.secondary.default.hex }}"
        theme[upload_end]="{{ colors.primary.default.hex }}"

        theme[process_start]="{{ colors.primary.default.hex }}"
        theme[process_mid]="{{ colors.secondary.default.hex }}"
        theme[process_end]="{{ colors.tertiary.default.hex }}"
      '';

      # -----------------------------------------------------------------------
      # Yazi
      # -----------------------------------------------------------------------

      "matugen/templates/yazi.toml".text = ''
        [mgr]
        cwd = { fg = "{{ colors.primary.default.hex }}", bold = true }

        find_keyword = {
          fg = "{{ colors.tertiary.default.hex }}",
          bold = true,
          italic = true
        }

        find_position = {
          fg = "{{ colors.secondary.default.hex }}",
          bold = true
        }

        marker_copied = {
          fg = "{{ colors.tertiary.default.hex }}",
          bg = "{{ colors.tertiary.default.hex }}"
        }

        marker_cut = {
          fg = "{{ colors.error.default.hex }}",
          bg = "{{ colors.error.default.hex }}"
        }

        marker_selected = {
          fg = "{{ colors.primary.default.hex }}",
          bg = "{{ colors.primary.default.hex }}"
        }

        border_style = {
          fg = "{{ colors.outline.default.hex }}"
        }

        [tabs]
        active = {
          fg = "{{ colors.on_primary.default.hex }}",
          bg = "{{ colors.primary.default.hex }}",
          bold = true
        }

        inactive = {
          fg = "{{ colors.on_surface_variant.default.hex }}",
          bg = "{{ colors.surface_container.default.hex }}"
        }

        [mode]
        normal_main = {
          fg = "{{ colors.on_primary.default.hex }}",
          bg = "{{ colors.primary.default.hex }}",
          bold = true
        }

        normal_alt = {
          fg = "{{ colors.primary.default.hex }}",
          bg = "{{ colors.surface_container.default.hex }}"
        }

        select_main = {
          fg = "{{ colors.on_secondary.default.hex }}",
          bg = "{{ colors.secondary.default.hex }}",
          bold = true
        }

        select_alt = {
          fg = "{{ colors.secondary.default.hex }}",
          bg = "{{ colors.surface_container.default.hex }}"
        }

        unset_main = {
          fg = "{{ colors.on_error.default.hex }}",
          bg = "{{ colors.error.default.hex }}",
          bold = true
        }

        unset_alt = {
          fg = "{{ colors.error.default.hex }}",
          bg = "{{ colors.surface_container.default.hex }}"
        }

        [status]
        perm_type = { fg = "{{ colors.tertiary.default.hex }}" }
        perm_read = { fg = "{{ colors.secondary.default.hex }}" }
        perm_write = { fg = "{{ colors.error.default.hex }}" }
        perm_exec = { fg = "{{ colors.primary.default.hex }}" }
        perm_sep = { fg = "{{ colors.outline.default.hex }}" }

        [filetype]
        rules = [
          { mime = "image/*", fg = "{{ colors.tertiary.default.hex }}" },
          { mime = "{audio,video}/*", fg = "{{ colors.secondary.default.hex }}" },
          { mime = "inode/empty", fg = "{{ colors.outline.default.hex }}" },
          { url = "*", is = "orphan", fg = "{{ colors.error.default.hex }}" },
          { url = "*/", fg = "{{ colors.primary.default.hex }}" }
        ]
      '';

      # -----------------------------------------------------------------------
      # VS Code
      #
      # The future VS Code Matugen extension consumes these cache files.
      # -----------------------------------------------------------------------

      "matugen/templates/vscode-colors".text = ''
        {{ colors.background.default.hex }}
        {{ colors.on_surface.default.hex }}
        {{ colors.secondary.default.hex }}
        {{ colors.tertiary.default.hex }}
        {{ colors.primary.default.hex }}
        {{ colors.tertiary.default.hex }}
        {{ colors.secondary_container.default.hex }}
        {{ colors.on_surface_variant.default.hex }}
        {{ colors.surface_variant.default.hex }}
        {{ colors.surface_tint.default.hex }}
        {{ colors.secondary.default.hex }}
        {{ colors.tertiary.default.hex }}
        {{ colors.primary.default.hex }}
        {{ colors.tertiary.default.hex }}
        {{ colors.primary_container.default.hex }}
        {{ colors.on_background.default.hex }}
      '';

      "matugen/templates/vscode-colors.json".text = ''
        {
          "checksum": "matugen",
          "alpha": "100",
          "special": {
            "background": "{{ colors.background.default.hex }}",
            "foreground": "{{ colors.on_background.default.hex }}",
            "cursor": "{{ colors.primary.default.hex }}"
          },
          "colors": {
            "color0": "{{ colors.background.default.hex }}",
            "color1": "{{ colors.on_surface.default.hex }}",
            "color2": "{{ colors.secondary.default.hex }}",
            "color3": "{{ colors.tertiary.default.hex }}",
            "color4": "{{ colors.primary.default.hex }}",
            "color5": "{{ colors.tertiary.default.hex }}",
            "color6": "{{ colors.secondary_container.default.hex }}",
            "color7": "{{ colors.on_surface_variant.default.hex }}",
            "color8": "{{ colors.surface_variant.default.hex }}",
            "color9": "{{ colors.surface_tint.default.hex }}",
            "color10": "{{ colors.secondary.default.hex }}",
            "color11": "{{ colors.tertiary.default.hex }}",
            "color12": "{{ colors.primary.default.hex }}",
            "color13": "{{ colors.tertiary.default.hex }}",
            "color14": "{{ colors.primary_container.default.hex }}",
            "color15": "{{ colors.on_background.default.hex }}"
          }
        }
      '';

      # Runtime-generated files stay outside the Nix store.
      "yazi/theme.toml".source = config.lib.file.mkOutOfStoreSymlink "${cacheDir}/yazi.toml";

      "btop/themes/matugen.theme".source = config.lib.file.mkOutOfStoreSymlink "${cacheDir}/btop.theme";
    };

    # Generate a sane initial dark palette only once.
    #
    # #7aa2f7 is our existing Tokyo Night blue and gives us a familiar
    # fallback until the first wallpaper is selected.
    home.activation.matugenBootstrap = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      mkdir -p '${cacheDir}'

      if [ ! -s '${cacheDir}/kitty.conf' ] \
        || [ ! -s '${cacheDir}/btop.theme' ] \
        || [ ! -s '${cacheDir}/yazi.toml' ]; then
        ${lib.getExe pkgs.matugen} \
          color hex '#7aa2f7' \
          -m dark
      fi
    '';
  };
}
