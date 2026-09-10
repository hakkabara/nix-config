target="${1:-${NIX_CONFIG_HOST:-$(</etc/hostname)}}"

echo "===== TARGET ====="
echo "$target"
echo

nix-check

echo
echo "===== NIXOS TEST: $target ====="

sudo nixos-rebuild test \
    --flake ".#$target"
