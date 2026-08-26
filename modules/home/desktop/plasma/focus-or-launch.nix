{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hakkabara.desktop.plasma.focusOrLaunch;

  focusOrLaunch = pkgs.writeShellApplication {
    name = "plasma-focus-or-launch";
    runtimeInputs = [ pkgs.kdotool ];

    text = ''
      if (( $# < 4 )); then
        echo "usage: plasma-focus-or-launch DESKTOP CLASS_REGEX -- COMMAND [ARG...]" >&2
        exit 64
      fi

      desktop="$1"
      class_regex="$2"
      shift 2

      if [[ "$1" != "--" ]]; then
        echo "ERROR: expected -- before launch command" >&2
        exit 64
      fi
      shift

      if (( $# == 0 )); then
        echo "ERROR: launch command is empty" >&2
        exit 64
      fi

      if [[ ! "$desktop" =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: desktop must be a positive integer" >&2
        exit 64
      fi

      mapfile -t windows < <(
        kdotool search \
          --desktop "$desktop" \
          --class "$class_regex" \
          2>/dev/null || true
      )

      for window in "''${windows[@]}"; do
        [[ -n "$window" ]] || continue

        # A minimized matching window should be restored rather than
        # causing a new application instance to be started.
        kdotool windowstate --remove MINIMIZED "$window" \
          >/dev/null 2>&1 || true

        if kdotool windowactivate "$window"; then
          kdotool windowraise "$window" \
            >/dev/null 2>&1 || true
          exit 0
        fi
      done

      # No usable existing window was found.
      exec "$@"
    '';
  };

  mkTargetLauncher =
    id: target:
    pkgs.writeShellApplication {
      name = "plasma-focus-or-launch-${id}";
      text = ''
        exec ${
          lib.escapeShellArgs (
            [
              (lib.getExe focusOrLaunch)
              (toString target.desktop)
              target.classRegex
              "--"
            ]
            ++ target.command
          )
        }
      '';
    };
in
{
  options.hakkabara.desktop.plasma.focusOrLaunch = {
    enable = lib.mkEnableOption "KWin/Wayland focus-or-launch application shortcuts";

    targets = lib.mkOption {
      default = { };

      description = "Applications managed by the Plasma focus-or-launch helper.";

      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable global shortcut name.";
            };

            key = lib.mkOption {
              type = lib.types.str;
              description = "Plasma global shortcut.";
            };

            desktop = lib.mkOption {
              type = lib.types.ints.positive;
              description = "Virtual desktop on which the application window is expected.";
            };

            classRegex = lib.mkOption {
              type = lib.types.str;
              description = "Regular expression matched against the KWin window class.";
            };

            command = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Command argv used only when no matching window exists.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.mapAttrsToList (id: target: {
      assertion = target.command != [ ];
      message = "focus-or-launch target '${id}' must define a non-empty command";
    }) cfg.targets;

    home.packages = [
      pkgs.kdotool
      focusOrLaunch
    ];

    programs.plasma.hotkeys.commands = lib.mapAttrs (
      id: target:
      let
        launcher = mkTargetLauncher id target;
      in
      {
        inherit (target) name key;
        command = "${launcher}/bin/plasma-focus-or-launch-${id}";
        logs.enabled = false;
      }
    ) cfg.targets;
  };
}
