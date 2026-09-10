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
    '';
  };
in
{
  options.hakkabara.cli.sshelf.enable = lib.mkEnableOption "sshelf SSH host manager";

  config = lib.mkIf cfg.enable {
    home.packages = [
      sshelfPackage
      sshelfImportSsh
    ];
  };
}
