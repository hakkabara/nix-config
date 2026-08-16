{ pkgs, ... }:

let
  repoRoot = ''
    repo="''${NIX_CONFIG_REPO:-$HOME/nix-config}"

    if [[ ! -d "$repo/.git" || ! -f "$repo/flake.nix" ]]; then
      echo "ERROR: nix-config repository not found at: $repo" >&2
      echo "Set NIX_CONFIG_REPO to override the repository location." >&2
      exit 1
    fi

    cd "$repo"
  '';
  nixFormat = pkgs.writeShellApplication {
    name = "nix-format";

    runtimeInputs = [
      pkgs.git
      pkgs.nix
    ];

    text = ''
      ${repoRoot}

      echo "===== FORMAT ====="
      nix fmt

      echo
      echo "===== CHANGES ====="
      git status --short
    '';
  };

  nixCheck = pkgs.writeShellApplication {
    name = "nix-check";

    runtimeInputs = [
      pkgs.git
      pkgs.nix
      pkgs.statix
      pkgs.deadnix
    ];

    text = ''
      ${repoRoot}

      echo "===== STATIX ====="
      statix check . -i hosts/surf-vm/hardware-configuration.nix

      echo
      echo "===== DEADNIX ====="
      deadnix --fail \
        --exclude hosts/surf-vm/hardware-configuration.nix \
        -- .

      echo
      echo "===== FLAKE ====="
      nix flake check

      echo
      echo "===== ALL CHECKS PASSED ====="
    '';
  };

  nixTest = pkgs.writeShellApplication {
    name = "nix-test";

    runtimeInputs = [
      pkgs.git
      nixCheck
    ];

    text = ''
      ${repoRoot}

      nix-check

      echo
      echo "===== NIXOS TEST ====="
      sudo nixos-rebuild test --flake .#surf-vm
    '';
  };

  nixSwitch = pkgs.writeShellApplication {
    name = "nix-switch";

    runtimeInputs = [
      pkgs.git
    ];

    text = ''
      ${repoRoot}

      echo "===== NIXOS SWITCH ====="
      sudo nixos-rebuild switch --flake .#surf-vm
    '';
  };
in
{
  home.packages = [
    pkgs.nixd
    pkgs.nixfmt
    pkgs.statix
    pkgs.deadnix
    pkgs.age
    pkgs.sops
    nixFormat
    nixCheck
    nixTest
    nixSwitch
  ];
}
