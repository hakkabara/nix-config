{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  cfg = config.hakkabara.cli.sshelf;

  sshelfPackage = pkgsUnstable.callPackage ../../../packages/sshelf/package.nix { };

  sshelfImportSsh = pkgs.writeShellApplication {
    name = "sshelf-import-ssh";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.python3
      sshelfPackage
    ];

    text = ''
            if [ "$#" -gt 1 ] || {
              [ "$#" -eq 1 ] && [ "$1" != "--dry-run" ]
            }; then
              echo "Usage: sshelf-import-ssh [--dry-run]" >&2
              exit 2
            fi

            real_home="$HOME"

            if [ -n "''${XDG_CONFIG_HOME:-}" ]; then
              real_xdg_config_home="$XDG_CONFIG_HOME"
            else
              real_xdg_config_home="$real_home/.config"
            fi

            if [ -n "''${XDG_DATA_HOME:-}" ]; then
              real_xdg_data_home="$XDG_DATA_HOME"
            else
              real_xdg_data_home="$real_home/.local/share"
            fi

            source_config="$real_home/.ssh/config"

            if [ ! -r "$source_config" ]; then
              echo "ERROR: cannot read $source_config" >&2
              exit 1
            fi

            tmp_home="$(mktemp -d /tmp/sshelf-import.XXXXXX)"

            cleanup() {
              rm -rf "$tmp_home"
            }

            trap cleanup EXIT HUP INT TERM

            install -d -m 700 "$tmp_home/.ssh"

            export REAL_HOME="$real_home"
            export TMP_HOME="$tmp_home"

            python3 <<'PY'
      from pathlib import Path
      import glob
      import os
      import shlex

      real_home = Path(os.environ["REAL_HOME"])
      tmp_home = Path(os.environ["TMP_HOME"])

      source = real_home / ".ssh/config"
      output = tmp_home / ".ssh/config"

      active_stack = set()


      def include_paths(expression: str):
          lexer = shlex.shlex(expression, posix=True)
          lexer.whitespace_split = True
          lexer.commenters = "#"

          for item in lexer:
              if item.startswith("~"):
                  item = str(real_home) + item[1:]

              path = Path(item)

              # OpenSSH user-config relative Includes are relative to ~/.ssh.
              if not path.is_absolute():
                  path = real_home / ".ssh" / path

              matches = sorted(glob.glob(str(path)))

              if not matches:
                  print(f"WARN: Include matched nothing: {path}")
                  continue

              for match in matches:
                  yield Path(match)


      def expand_file(path: Path):
          path = path.expanduser().resolve()

          if path in active_stack:
              raise RuntimeError(f"recursive Include detected: {path}")

          if not path.is_file():
              raise RuntimeError(f"Include is not a readable file: {path}")

          active_stack.add(path)
          result = []

          try:
              for line in path.read_text().splitlines():
                  stripped = line.strip()

                  if not stripped.lower().startswith("include "):
                      result.append(line)
                      continue

                  expression = stripped.split(None, 1)[1]

                  for included in include_paths(expression):
                      result.append(f"# BEGIN expanded Include: {included}")
                      result.extend(expand_file(included))
                      result.append(f"# END expanded Include: {included}")
          finally:
              active_stack.remove(path)

          return result


      flattened = expand_file(source)

      output.write_text("\n".join(flattened) + "\n")
      output.chmod(0o600)

      print(f"PASS: expanded SSH config ({len(flattened)} lines)")
      PY

            HOME="$tmp_home" \
            XDG_CONFIG_HOME="$real_xdg_config_home" \
            XDG_DATA_HOME="$real_xdg_data_home" \
              sshelf import "$@"

            # sshelf stores ~/... identity files as absolute paths, and ~ was
            # the temporary home during the import. Point them back at the
            # real home; this also repairs hosts of earlier imports.
            hosts_file="$real_xdg_config_home/sshelf/hosts.toml"

            if [ "$#" -eq 0 ] && [ -f "$hosts_file" ] &&
              grep -q '/tmp/sshelf-import\.[A-Za-z0-9]*/' "$hosts_file"; then
              sed -i "s|/tmp/sshelf-import\.[A-Za-z0-9]*/|$real_home/|g" "$hosts_file"
              echo "PASS: identity file paths point at $real_home"
            fi
    '';
  };

  settingsFile = (pkgs.formats.toml { }).generate "sshelf-config.toml" cfg.settings;
in
{
  options.hakkabara.cli.sshelf = {
    enable = lib.mkEnableOption "sshelf SSH host manager";

    autoImport.enable = lib.mkEnableOption ''
      importing the hosts of ~/.ssh/config into sshelf at login and after
      every Home Manager activation. The import only adds hosts whose name
      sshelf does not know yet; it never changes or removes one
    '';

    settings = lib.mkOption {
      inherit (pkgs.formats.toml { }) type;
      default = { };
      example = {
        accent = "blue";
        tmux = "window";
      };
      description = ''
        Start values for ~/.config/sshelf/config.toml. sshelf saves its
        settings screen (F2) to that file, so it is only written while it
        does not exist; an existing file is left alone.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      sshelfPackage
      sshelfImportSsh
    ];

    home.activation = {
      sshelfSettings = lib.mkIf (cfg.settings != { }) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          sshelf_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/sshelf"
          if [ ! -e "$sshelf_dir/config.toml" ]; then
            run install -d -m 700 "$sshelf_dir"
            run install -m 600 ${settingsFile} "$sshelf_dir/config.toml"
          fi
        ''
      );

      # A changed SSH config does not change the unit, so sd-switch would
      # not start it again. No user manager (boot, first activation) is
      # fine: the unit also runs at login.
      sshelfAutoImport = lib.mkIf cfg.autoImport.enable (
        lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
          run ${pkgs.systemd}/bin/systemctl --user start --no-block sshelf-auto-import.service || true
        ''
      );
    };

    systemd.user.services.sshelf-auto-import = lib.mkIf cfg.autoImport.enable {
      Unit = {
        Description = "Import the hosts of ~/.ssh/config into sshelf";
        ConditionPathExists = "%h/.ssh/config";
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe sshelfImportSsh;
        # The import lists every host name; keep them out of the journal.
        StandardOutput = "null";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
