{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hakkabara.tools.deployment;
in
{
  options.hakkabara.tools.deployment.enable =
    lib.mkEnableOption "deployment helper tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "deploy-status" ''
        set -euo pipefail

        echo "===== DEPLOYMENT STATUS ====="

        echo
        echo "Host:"
        hostname

        echo
        echo "Nix:"
        nix --version

        echo
        echo "Deployment LAN:"

        if ip addr show ens37 >/dev/null 2>&1; then
          echo "PASS: deployment interface exists"
          ip -4 addr show dev ens37
        else
          echo "FAIL: deployment interface missing"
        fi

        echo
        echo "Harmonia:"

        if systemctl is-active --quiet harmonia.socket; then
          echo "PASS: Harmonia active"
        else
          echo "FAIL: Harmonia inactive"
        fi
      '')
    ];
  };
}
