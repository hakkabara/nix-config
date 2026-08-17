echo "===== FORMAT ====="
nix fmt

echo
echo "===== CHANGES ====="
git status --short
