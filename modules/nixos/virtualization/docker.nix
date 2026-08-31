{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.virtualization.docker;

  dockerPreload = pkgs.writeShellApplication {
    name = "docker-preload";

    runtimeInputs = [
      pkgs.docker
    ];

    text = ''
      images=(${lib.escapeShellArgs cfg.preloadImages})

      if (( ''${#images[@]} == 0 )); then
        echo "No Docker preload images configured."
        exit 0
      fi

      present=0
      pulled=0
      failed=0

      echo "============================================================"
      echo "DOCKER IMAGE PRELOAD"
      echo "============================================================"

      for image in "''${images[@]}"; do
        echo
        echo "===== $image ====="

        if docker image inspect "$image" >/dev/null 2>&1; then
          echo "PASS: already present"
          present=$((present + 1))
          continue
        fi

        echo "PULL: image missing"

        if docker pull "$image"; then
          echo "PASS: pulled"
          pulled=$((pulled + 1))
        else
          echo "FAIL: pull failed"
          failed=$((failed + 1))
        fi
      done

      echo
      echo "============================================================"
      printf 'ALREADY PRESENT: %d\n' "$present"
      printf 'PULLED:          %d\n' "$pulled"
      printf 'FAILED:          %d\n' "$failed"
      echo "============================================================"

      (( failed == 0 ))
    '';
  };
in
{
  options.hakkabara.virtualization.docker = {
    enable = lib.mkEnableOption "Docker container runtime";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mko" ];

      description = ''
        Users that may access the rootful Docker daemon without sudo.

        Membership in the docker group is effectively root-equivalent.
      '';
    };

    preloadImages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];

      description = ''
        Version-pinned Docker images used by local tooling.

        Images are not pulled automatically during boot. Run docker-preload
        manually to fetch images that are not already present.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      extraPackages = [ pkgs.nftables ];

      daemon.settings = {
        # Default docker0 bridge.
        bip = "172.31.255.1/28";

        # Automatically created Docker/Compose networks.
        #
        # Split 172.30.0.0/16 into /28 networks:
        # 4096 possible Docker networks with enough space
        # for roughly 13 containers per network.
        "default-address-pools" = [
          {
            base = "172.30.0.0/16";
            size = 28;
          }
        ];
      };
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "docker" ];
    });

    environment.systemPackages = lib.optional (cfg.preloadImages != [ ]) dockerPreload;
  };
}
