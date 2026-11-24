{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.tailorkey;

  # The cheats file plus the sections other modules add to its pages.
  cheats = pkgs.writeText "tailorkey-cheats.json" (
    builtins.toJSON {
      pages = map (
        page:
        page
        // lib.optionalAttrs (cfg.extraSections ? ${page.key}) {
          extraSections = cfg.extraSections.${page.key};
        }
      ) (builtins.fromJSON (builtins.readFile cfg.cheats)).pages;
    }
  );

  # One PNG per useful layer plus the combo pages, rendered at build time from
  # the Glove80 Layout Editor export (my.moergo.com), followed by one page per
  # program in the cheats file (Vim, LazyVim, lnav, niri). The niri page is
  # built from the generated niri config, so own binds show up by themselves.
  # Fonts are pinned so the sandboxed rsvg-convert finds DejaVu Sans.
  pages =
    pkgs.runCommand "tailorkey-layers"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.librsvg
        ];
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
      }
      ''
        mkdir -p svg "$out"
        python3 -I ${./render.py} ${cfg.layout} svg ${cheats} ${
          lib.optionalString (cfg.niriConfig != null) cfg.niriConfig
        }
        for f in svg/*.svg; do
          name="$(basename "$f" .svg)"
          rsvg-convert "$f" -o "$out/$name.png"
        done
        cp svg/*.txt "$out"
      '';

  # Ctrl+F in the viewer: the pages are pictures, so the search filters the
  # text of the current page (NN-<name>.txt next to the PNG) in a small
  # terminal. Typing narrows the lines, Esc or Enter closes it.
  search = pkgs.writeShellApplication {
    name = "tk-search";
    runtimeInputs = [
      pkgs.fzf
      pkgs.kitty
    ];
    text = ''
      lines="''${1%.png}.txt"
      [ -r "$lines" ] || exit 0
      # shellcheck disable=SC2016 # $1 belongs to the inner shell
      exec kitty --class tailorkey-search --title "tk: Suche" sh -c '
        fzf --exact --ignore-case --no-sort --layout=reverse --info=inline \
          --prompt="Suche > " --header="Tippen filtert · Esc schließt" <"$1" >/dev/null || true
      ' sh "$lines"
    '';
  };

  # Toggle: a second call closes the viewer again.
  tk = pkgs.writeShellApplication {
    name = "tk";
    runtimeInputs = [
      pkgs.imv
      pkgs.procps
    ];
    text = ''
      if pkill -f -- "${pages}/01-"; then
        exit 0
      fi
      # Pages are exactly 1400x730 and share the background colour, so no
      # bars show even if the compositor picks another size. 1-9 and 0 jump
      # to a page; a cheat page NN-cheat-<letter>.png is reached with its
      # letter. Ctrl+F searches the text of the page shown.
      args=(-s shrink -b 1a1b26 -W 1400 -H 730 -c 'bind <Escape> quit')
      # shellcheck disable=SC2016 # imv sets $imv_current_file for the command
      args+=(-c 'bind <Ctrl+f> exec ${lib.getExe search} "$imv_current_file"')
      for n in 1 2 3 4 5 6 7 8 9; do
        args+=(-c "bind $n goto $n")
      done
      args+=(-c 'bind 0 goto 10')
      for page in ${pages}/*-cheat-*.png; do
        [ -e "$page" ] || continue
        name="''${page##*/}"
        name="''${name%.png}"
        args+=(-c "bind ''${name##*-} goto $((10#''${name%%-*}))")
      done
      exec imv-wayland "''${args[@]}" ${pages}/*.png
    '';
  };
in
{
  options.hakkabara.apps.tailorkey = {
    enable = lib.mkEnableOption "TailorKey/Glove80 layer cheat sheet (`tk`)";

    layout = lib.mkOption {
      type = lib.types.path;
      default = ./layout.json;
      description = "Glove80 Layout Editor JSON export to render.";
    };

    cheats = lib.mkOption {
      type = lib.types.path;
      default = ./cheats.json;
      description = ''
        Shortcut tables of programs, one page each after the layer pages.
        `key` is the letter that jumps to the page.
      '';
    };

    extraSections = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.attrsOf lib.types.anything));
      default = { };
      example = {
        b = [
          {
            title = "Intern";
            keyWidth = 200;
            rows = [
              [
                "vpn-up"
                "VPN verbinden"
              ]
            ];
          }
        ];
      };
      description = ''
        Sections other modules add to a page of the cheats file, by the
        page's key (for example `b`, the page of own commands). Each goes to
        the shortest column.
      '';
    };

    niriConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default =
        let
          text = (config.xdg.configFile."niri/config.kdl" or { }).text or null;
        in
        if text == null then null else pkgs.writeText "niri-config.kdl" text;
      defaultText = lib.literalExpression "the generated ~/.config/niri/config.kdl, if any";
      description = ''
        niri config whose binds fill the niri page; without it that page is
        left out.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pages;
      description = "Rendered layer pages (PNG), for window rules and tests.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ tk ];
  };
}
