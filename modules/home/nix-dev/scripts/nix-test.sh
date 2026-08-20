nix-check

echo
echo "===== NIXOS TEST ====="

sudo nixos-rebuild test --flake .#surf-vm
