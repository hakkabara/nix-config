{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.nix.cacheRetention;

  deployCachePin = pkgs.writeShellApplication {
    name = "deploy-cache-pin";

    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
      pkgs.util-linux
    ];

    text = ''
      if [ "$#" -ne 2 ]; then
        echo "Usage: deploy-cache-pin <host> <store-path>" >&2
        exit 2
      fi

      if [ "$(id -u)" -ne 0 ]; then
        echo "ERROR: deploy-cache-pin must run as root." >&2
        exit 1
      fi

      host="$1"
      requested_path="$2"

      root_dir=${lib.escapeShellArg cfg.rootDir}
      lock_file=${lib.escapeShellArg cfg.lockFile}

      case "$host" in
        ""|*[!a-z0-9-]*|-*|*-)
          echo "ERROR: invalid host name: $host" >&2
          exit 1
          ;;
      esac

      case "$requested_path" in
        /nix/store/*)
          ;;
        *)
          echo "ERROR: path must be below /nix/store." >&2
          exit 1
          ;;
      esac

      target="$(readlink -e -- "$requested_path")" || {
        echo "ERROR: store path does not exist: $requested_path" >&2
        exit 1
      }

      case "$target" in
        /nix/store/*)
          ;;
        *)
          echo "ERROR: resolved path escaped /nix/store: $target" >&2
          exit 1
          ;;
      esac

      echo "Validating closure: $target"

      if ! nix-store --query --requisites "$target" >/dev/null; then
        echo "ERROR: Nix cannot resolve the complete closure." >&2
        exit 1
      fi

      exec 9>"$lock_file"
      flock --exclusive 9

      host_dir="$root_dir/$host"
      current="$host_dir/current"
      previous="$host_dir/previous"

      mkdir -p -- "$host_dir"

      old_current=""

      if [ -L "$current" ]; then
        old_current="$(readlink -e -- "$current")" || {
          echo "ERROR: current is a broken GC root." >&2
          exit 1
        }
      elif [ -e "$current" ]; then
        echo "ERROR: current exists but is not a symlink." >&2
        exit 1
      fi

      if [ "$old_current" = "$target" ]; then
        echo "UNCHANGED: $host current already points to:"
        echo "$target"

        if [ -L "$previous" ]; then
          echo "previous -> $(readlink -f -- "$previous")"
        fi

        exit 0
      fi

      tmp_current="$host_dir/.current.$$.tmp"
      tmp_previous="$host_dir/.previous.$$.tmp"

      cleanup() {
        rm -f -- "$tmp_current" "$tmp_previous"
      }

      trap cleanup EXIT INT TERM

      # The temporary link itself lives below gcroots, so the new target stays
      # protected while current/previous are rotated.
      ln -s -- "$target" "$tmp_current"

      if [ -n "$old_current" ]; then
        ln -s -- "$old_current" "$tmp_previous"

        # Protect the former current generation before replacing current.
        mv -Tf -- "$tmp_previous" "$previous"
      fi

      mv -Tf -- "$tmp_current" "$current"

      trap - EXIT INT TERM

      echo "PINNED: $host"
      echo "current  -> $(readlink -f -- "$current")"

      if [ -L "$previous" ]; then
        echo "previous -> $(readlink -f -- "$previous")"
      fi
    '';
  };
in
{
  options.hakkabara.nix.cacheRetention = {
    enable = lib.mkEnableOption "DeployVM cache GC-root retention tooling";

    rootDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/var/nix/gcroots/hakkabara";
      description = "Root directory containing per-host cache-retention GC roots.";
    };

    lockFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/lock/nix-store-maintenance.lock";
      description = ''
        Store-maintenance lock shared with garbage collection and optimisation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/nix/var/nix/gcroots/" cfg.rootDir;
        message = ''
          hakkabara.nix.cacheRetention.rootDir must be below
          /nix/var/nix/gcroots/.
        '';
      }
    ];

    environment.systemPackages = [
      deployCachePin
    ];
  };
}
