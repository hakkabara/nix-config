{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.deployment;

  deployStatus = pkgs.writeShellApplication {
    name = "deploy-status";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.iproute2
      pkgs.systemd
    ];

    text = builtins.readFile ./scripts/deploy-status;
  };

  deployRepoSync = pkgs.writeShellApplication {
    name = "deploy-repo-sync";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
    ];

    text = builtins.readFile ./scripts/deploy-repo-sync;
  };
  deployBuild = pkgs.writeShellApplication {
    name = "deploy-build";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.sudo
    ];

    text = builtins.readFile ./scripts/deploy-build;
  };

in
{
  options.hakkabara.tools.deployment.enable = lib.mkEnableOption "deployment helper tools";

  config = lib.mkIf cfg.enable {
    # Mutable deployment state belongs on the dedicated persistent Btrfs
    # subvolume rather than in the system configuration or the Nix store.
    systemd.tmpfiles.rules = [
      "d /persist/deployment 0750 mko users -"
      "d /persist/deployment/repos 0750 mko users -"
    ];

    environment.systemPackages = [
      deployStatus
      deployRepoSync
      deployBuild
    ];
  };
}
