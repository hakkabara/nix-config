target="${1:-${NIX_CONFIG_HOST:-$(</etc/hostname)}}"

echo "===== TARGET ====="
echo "$target"
echo

echo "===== NIXOS SWITCH: $target ====="

sudo nixos-rebuild switch \
    --flake ".#$target"
