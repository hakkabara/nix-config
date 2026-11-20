# Provision the repositories from the decrypted SOPS document (systemd
# credential "repositories") for $ADMIN_USER. Runs as the forgejo user;
# see systemd.services.forgejo-repositories.
set -euo pipefail

token=""

api() {
    local method=$1 path=$2
    shift 2
    curl --silent --show-error --fail-with-body \
        --request "$method" \
        --header "Authorization: token $token" \
        --header "Content-Type: application/json" \
        "$@" \
        "$FORGEJO_API$path"
}

token_works() {
    [ -n "$token" ] && api GET /user --output /dev/null 2>/dev/null
}

# Forgejo may still be starting after a switch.
for _ in $(seq 60); do
    if curl --silent --output /dev/null "$FORGEJO_API/version"; then
        break
    fi
    sleep 2
done

if [ -s "$TOKEN_FILE" ]; then
    token=$(cat "$TOKEN_FILE")
fi

if ! token_works; then
    echo "Creating a new provisioning access token"
    mkdir -p "$(dirname "$TOKEN_FILE")"
    forgejo admin user generate-access-token \
        --username "$ADMIN_USER" \
        --token-name "nixos-provisioning-$(date +%s)" \
        --scopes "write:repository,write:user" \
        --raw >"$TOKEN_FILE.new"
    mv "$TOKEN_FILE.new" "$TOKEN_FILE"
    token=$(cat "$TOKEN_FILE")
    token_works
fi

# YAML document -> one JSON object per enabled repository, with defaults.
yq --output-format=json '.repositories // []' "$CREDENTIALS_DIRECTORY/repositories" |
    jq --compact-output '
        .[]
        | select(.enable != false)
        | {name, description: (.description // "")}
          + (if .mirror then {mirror: ({interval: "1h"} + .mirror)} else {mirror: null} end)
    ' |
    while read -r repo; do
        name=$(jq --raw-output '.name' <<<"$repo")
        if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "Invalid repository name in the SOPS document: $name" >&2
            exit 1
        fi
        path="/repos/$ADMIN_USER/$name"

        if api GET "$path" --output /dev/null 2>/dev/null; then
            # Reconcile the mutable settings of an existing repository.
            jq '{description} + (if .mirror then {mirror_interval: .mirror.interval} else {} end)' \
                <<<"$repo" | api PATCH "$path" --data @- --output /dev/null
            echo "Repository up to date: $ADMIN_USER/$name"
            continue
        fi

        if [ "$(jq --raw-output '.mirror != null' <<<"$repo")" = true ]; then
            # Credentials travel only through stdin, never through argv.
            jq --arg owner "$ADMIN_USER" '{
                    clone_addr: .mirror.url,
                    repo_name: .name,
                    repo_owner: $owner,
                    description,
                    mirror: true,
                    mirror_interval: .mirror.interval,
                    private: true,
                    service: "git"
                }
                + (if .mirror.username then {auth_username: .mirror.username} else {} end)
                + (if .mirror.password then {auth_password: .mirror.password} else {} end)' \
                <<<"$repo" | api POST /repos/migrate --data @- --output /dev/null
            echo "Pull mirror created: $ADMIN_USER/$name"
        else
            jq '{name, description, private: true, default_branch: "main"}' \
                <<<"$repo" | api POST /user/repos --data @- --output /dev/null
            echo "Repository created: $ADMIN_USER/$name"
        fi
    done
