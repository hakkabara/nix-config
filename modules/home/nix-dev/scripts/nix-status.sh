print_value() {
  printf "  %-20s %s\n" "$1:" "$2"
}

echo "Nix Config Status"
echo "────────────────────────────────────────"
echo

#
# Repository
#

echo "Repository"

branch="$(git branch --show-current)"

if [[ -z "$branch" ]]; then
  branch="detached HEAD"
fi

if [[ -z "$(git status --porcelain)" ]]; then
  git_state="OK (clean)"
else
  git_state="WARN (dirty)"
fi

commit="$(git rev-parse --short HEAD)"

print_value "Path" "$PWD"
print_value "Branch" "$branch"
print_value "Git" "$git_state"
print_value "Commit" "$commit"

origin="$(git remote get-url origin 2>/dev/null || true)"

if [[ -n "$origin" ]]; then
  print_value "Origin" "$origin"
else
  print_value "Origin" "WARN (not configured)"
fi

if upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  read -r ahead behind < <(
    git rev-list --left-right --count "HEAD...$upstream"
  )

  print_value "Upstream" "$upstream"
  print_value "Tracking" "$ahead ahead / $behind behind"
else
  print_value "Upstream" "WARN (none configured)"
fi

#
# System
#

echo
echo "System"

hostname_value="$(hostnamectl --static 2>/dev/null || true)"

if [[ -z "$hostname_value" ]]; then
  hostname_value="unknown"
fi

print_value "Hostname" "$hostname_value"
print_value "Flake target" "surf-vm"

if command -v nixos-version >/dev/null 2>&1; then
  nixos_version="$(nixos-version)"
  print_value "NixOS" "$nixos_version"
else
  print_value "NixOS" "WARN (unknown)"
fi

system_profile="$(readlink /nix/var/nix/profiles/system 2>/dev/null || true)"

case "$system_profile" in
  *system-*-link)
    generation="$(basename "$system_profile")"
    generation="${generation#system-}"
    generation="${generation%-link}"

    print_value "Generation" "$generation"
    ;;
  *)
    print_value "Generation" "WARN (unknown)"
    ;;
esac

#
# Home Manager
#

echo
echo "Home Manager"

hm_state="$(systemctl is-active home-manager-hakkabara.service 2>/dev/null || true)"

if [[ "$hm_state" == "active" ]]; then
  print_value "hakkabara" "OK (active)"
else
  print_value "hakkabara" "WARN (${hm_state:-unknown})"
fi

#
# Runtime secrets
#

echo
echo "Runtime Secrets"

check_secret() {
  local label="$1"
  local path="$2"
  local permissions

  if [[ -r "$path" ]]; then
    permissions="$(stat -Lc '%U:%G %a' "$path")"
    print_value "$label" "OK ($permissions)"
  elif [[ -e "$path" ]]; then
    print_value "$label" "WARN (not readable)"
  else
    print_value "$label" "ERROR (missing)"
  fi
}

check_secret \
  "ssh-system-key" \
  "/run/secrets/ssh-system-key"

check_secret \
  "personal-infra" \
  "/run/secrets/ssh-personal-infra"

#
# VMware
#

echo
echo "VMware"

mount_info="$(findmnt -rn -M /data -o SOURCE,FSTYPE 2>/dev/null || true)"

if [[ -n "$mount_info" ]]; then
  print_value "/data" "OK ($mount_info)"
else
  print_value "/data" "WARN (not mounted)"
fi

#
# Workflow
#

echo
echo "Workflow"

for command in \
  nix-format \
  nix-check \
  nix-status \
  nix-test \
  nix-switch; do

  if command -v "$command" >/dev/null 2>&1; then
    print_value "$command" "OK"
  else
    print_value "$command" "ERROR (not found)"
  fi
done
