fail() {
  echo "ERROR: $*" >&2
  exit 1
}

check_sops_file() {
  local file="$1"
  local input_type
  local status

  case "$file" in
    *.yaml|*.yml)
      input_type="yaml"
      ;;
    *.json)
      input_type="json"
      ;;
    *.env)
      input_type="dotenv"
      ;;
    *.ini)
      input_type="ini"
      ;;
    *)
      input_type="binary"
      ;;
  esac

  if ! status="$(sops filestatus --input-type "$input_type" "$file")"; then
    fail "Unable to inspect SOPS file: $file"
  fi

  if [[ "$status" != *'"encrypted":true'* ]]; then
    echo "$status" >&2
    fail "File below secrets/ is not SOPS encrypted: $file"
  fi

  echo "OK: $file"
}

echo "===== STATIX ====="
statix check . -i hosts/surf-vm/hardware-configuration.nix

echo
echo "===== DEADNIX ====="
deadnix --fail \
  --exclude hosts/surf-vm/hardware-configuration.nix \
  -- .

echo
echo "===== SOPS ENCRYPTION STATUS ====="

while IFS= read -r -d "" file; do
  check_sops_file "$file"
done < <(find secrets -type f -print0)

echo
echo "===== SECRET POLICY ====="

age_private_marker="AGE-SECRET""-KEY-1"

if git grep -nF "$age_private_marker" -- .; then
  fail "Age private identity found in tracked repository content."
fi

if git grep -nE \
  -e '(initialPassword|password|initialHashedPassword|hashedPassword)[[:space:]]*=[[:space:]]*"[^"]+"' \
  -- '*.nix'; then
  fail "Inline NixOS password or password hash found."
fi

if git grep -nE \
  -e 'mode[[:space:]]*=[[:space:]]*"0?[0-7]{2}[1-7]"' \
  -- 'hosts/**/secrets.nix'; then
  fail "A SOPS secret appears to grant permissions to other users."
fi

echo "OK: repository secret policies"

echo
echo "===== GITLEAKS: WORKTREE ====="

gitleaks dir \
  --config .gitleaks.toml \
  --redact \
  --no-banner \
  .

echo
echo "===== GITLEAKS: GIT HISTORY ====="

gitleaks git \
  --config .gitleaks.toml \
  --redact \
  --no-banner \
  .

echo
echo "===== FLAKE ====="

nix flake check

echo
echo "===== ALL CHECKS PASSED ====="
