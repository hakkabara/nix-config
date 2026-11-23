{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.apps.tailorkey;

  # One PNG per useful layer plus the combo pages, rendered at build time from
  # the Glove80 Layout Editor export (my.moergo.com), followed by one page per
  # program in the cheats file (Vim, LazyVim, lnav). Fonts are pinned so the
  # sandboxed rsvg-convert finds DejaVu Sans.
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
        python3 -I ${./render.py} ${cfg.layout} svg ${cfg.cheats}
        for f in svg/*.svg; do
          name="$(basename "$f" .svg)"
          rsvg-convert "$f" -o "$out/$name.png"
        done
      '';

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
      # letter.
      args=(-s shrink -b 1a1b26 -W 1400 -H 730 -c 'bind <Escape> quit')
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
