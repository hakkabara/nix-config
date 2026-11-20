# forgejo-mirror-sync [REPO...]
#
# Pull every pull mirror of the administrator (or only the named ones) from
# its upstream now and wait until Forgejo has finished. Run this before a
# build from a mirror so it never uses a stale state. Needs root to read
# the provisioning token of forgejo-repositories.service.
set -euo pipefail

: "${FORGEJO_API:?}" "${ADMIN_USER:?}" "${TOKEN_FILE:?}"
timeout_seconds=${FORGEJO_MIRROR_SYNC_TIMEOUT:-180}

if [ ! -r "$TOKEN_FILE" ]; then
    echo "Cannot read $TOKEN_FILE. Run as root after forgejo-repositories.service." >&2
    exit 1
fi
token=$(cat "$TOKEN_FILE")

api() {
    local method=$1 path=$2
    shift 2
    curl --silent --show-error --fail-with-body \
        --request "$method" \
        --header "Authorization: token $token" \
        "$@" \
        "$FORGEJO_API$path"
}

if [ "$#" -gt 0 ]; then
    repos=("$@")
else
    mapfile -t repos < <(api GET "/user/repos?limit=50" |
        jq --raw-output --arg owner "$ADMIN_USER" '.[] | select(.mirror and .owner.login == $owner) | .name')
fi

if [ "${#repos[@]}" -eq 0 ]; then
    echo "No pull mirrors found."
    exit 0
fi

for repo in "${repos[@]}"; do
    path="/repos/$ADMIN_USER/$repo"
    before=$(api GET "$path" | jq --raw-output '.mirror_updated')
    api POST "$path/mirror-sync" --output /dev/null

    deadline=$((SECONDS + timeout_seconds))
    while [ "$(api GET "$path" | jq --raw-output '.mirror_updated')" = "$before" ]; do
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "Timeout: $ADMIN_USER/$repo was not updated within ${timeout_seconds}s" >&2
            exit 1
        fi
        sleep 2
    done

    branch=$(api GET "$path" | jq --raw-output '.default_branch')
    head=$(api GET "$path/branches/$branch" | jq --raw-output '.commit.id[0:7]')
    echo "Mirror synced: $ADMIN_USER/$repo ($branch at $head)"
done
