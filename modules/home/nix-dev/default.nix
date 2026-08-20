{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.nixDev;

  repoRoot = ''
    repo="''${NIX_CONFIG_REPO:-$HOME/nix-config}"

    if [[ ! -d "$repo/.git" || ! -f "$repo/flake.nix" ]]; then
      echo "ERROR: nix-config repository not found at: $repo" >&2
      echo "Set NIX_CONFIG_REPO to override the repository location." >&2
      exit 1
    fi

    cd "$repo"
  '';

  mkRepoTool =
    {
      name,
      runtimeInputs ? [ ],
      script,
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = repoRoot + builtins.readFile script;
    };

  nixFormat = mkRepoTool {
    name = "nix-format";
    runtimeInputs = [
      pkgs.git
      pkgs.nix
    ];
    script = ./scripts/nix-format.sh;
  };

  nixCheck = mkRepoTool {
    name = "nix-check";
    runtimeInputs = [
      pkgs.git
      pkgs.nix
      pkgs.statix
      pkgs.deadnix
      pkgs.sops
      pkgs.gitleaks
      pkgs.findutils
    ];
    script = ./scripts/nix-check.sh;
  };

  nixStatus = mkRepoTool {
    name = "nix-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.systemd
      pkgs.util-linux
    ];
    script = ./scripts/nix-status.sh;
  };

  nixTest = mkRepoTool {
    name = "nix-test";
    runtimeInputs = [
      pkgs.git
      nixCheck
    ];
    script = ./scripts/nix-test.sh;
  };

  nixSwitch = mkRepoTool {
    name = "nix-switch";
    runtimeInputs = [
      pkgs.git
    ];
    script = ./scripts/nix-switch.sh;
  };
in
{
  options.hakkabara.nixDev.enable = lib.mkEnableOption "Nix configuration development tools";

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.nixd
      pkgs.nixfmt
      pkgs.statix
      pkgs.deadnix
      pkgs.age
      pkgs.sops
      pkgs.gitleaks

      nixFormat
      nixCheck
      nixStatus
      nixTest
      nixSwitch
    ];
  };
}
