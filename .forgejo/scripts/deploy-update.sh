#!/usr/bin/env bash
# deploy-update.sh - maintain the `deploy` branch from CI.
#
#   deploy-update.sh publish HOST STORE_PATH
#       Record STORE_PATH for HOST (hosts/HOST) and the commit that produced it
#       (rev/HOST). Skips if a newer commit was already published for HOST.
#   deploy-update.sh prune HOST...
#       Remove entries for every host NOT in the argument list.
#
# Run from the root of a full-history checkout (fetch-depth: 0) of the
# repository. Needs TOKEN_FORGEJO and GITHUB_SHA in the environment.
set -euo pipefail

: "${TOKEN_FORGEJO:?TOKEN_FORGEJO is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

MAIN_REPO="$PWD"
REPO_URL="$(git remote get-url origin)"
SRC_SHA="$GITHUB_SHA"
ATTEMPTS=5

# Authenticate through environment-provided git config, so the token is never
# written to disk or embedded in a URL.
auth="$(printf 'x-access-token:%s' "$TOKEN_FORGEJO" | base64 -w0)"
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0="http.https://git.lumilukko.com/.extraheader"
export GIT_CONFIG_VALUE_0="AUTHORIZATION: basic ${auth}"
export GIT_CONFIG_KEY_1="user.name"
export GIT_CONFIG_VALUE_1="deploy-publisher"
export GIT_CONFIG_KEY_2="user.email"
export GIT_CONFIG_VALUE_2="deploy-publisher@lumilukko.com"

WORK=""
cleanup() { [[ -z "$WORK" ]] || rm -rf "$WORK"; }
trap cleanup EXIT

# Fresh clone of deploy (or an empty orphan repo if the branch doesn't exist).
# A network failure must not be mistaken for a missing branch.
fresh_clone() {
    cleanup
    WORK="$(mktemp -d)"

    local rc=0
    git ls-remote --exit-code --heads "$REPO_URL" deploy >/dev/null 2>&1 || rc=$?

    case "$rc" in
        0) git clone --quiet --branch deploy --single-branch "$REPO_URL" "$WORK/deploy" ;;
        2)
            echo "No deploy branch yet, creating an orphan one."
            git init --quiet -b deploy "$WORK/deploy"
            git -C "$WORK/deploy" remote add origin "$REPO_URL"
            ;;
        *) echo "ERROR: cannot reach $REPO_URL (ls-remote exit $rc)" >&2; return 1 ;;
    esac
}

backoff() { sleep $(( RANDOM % 5 + 2 )); }

publish() {
    local host="$1" path="$2" attempt old_rev

    [[ "$host" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "ERROR: invalid host '$host'" >&2; exit 2; }
    [[ "$path" =~ ^/nix/store/[0-9a-z]{32}-[^/[:space:]]+$ ]] ||
        { echo "ERROR: invalid store path '$path'" >&2; exit 2; }

    for (( attempt = 1; attempt <= ATTEMPTS; attempt++ )); do
        if ! fresh_clone; then backoff; continue; fi
        cd "$WORK/deploy"

        # Never move a host backwards: if the commit already recorded for this
        # host is newer than ours (we are not its descendant), do nothing.
        old_rev=""
        [[ -f "rev/$host" ]] && old_rev="$(tr -d '[:space:]' < "rev/$host")"

        if [[ -n "$old_rev" && "$old_rev" != "$SRC_SHA" ]] &&
           git -C "$MAIN_REPO" cat-file -e "${old_rev}^{commit}" 2>/dev/null &&
           ! git -C "$MAIN_REPO" merge-base --is-ancestor "$old_rev" "$SRC_SHA"; then
            echo "deploy already has a newer commit for ${host} (${old_rev}); skipping."
            return 0
        fi

        mkdir -p hosts rev
        printf '%s\n' "$path"    > "hosts/$host"
        printf '%s\n' "$SRC_SHA" > "rev/$host"
        git add -A

        if git diff --cached --quiet; then
            echo "deploy entry for ${host} unchanged."
            return 0
        fi

        git commit --quiet -m "deploy: ${host} ${SRC_SHA:0:8}" -m "${host}: ${path}"

        # Never force: history on deploy is the audit trail.
        if git push --quiet origin HEAD:refs/heads/deploy; then
            echo "Published ${host} -> ${path} (${SRC_SHA:0:8})."
            return 0
        fi

        echo "Push rejected (attempt ${attempt}/${ATTEMPTS}), retrying..." >&2
        cd "$MAIN_REPO"
        backoff
    done

    echo "ERROR: failed to publish ${host} to deploy" >&2
    exit 1
}

prune() {
    local keep=" $* " attempt f name removed

    for (( attempt = 1; attempt <= ATTEMPTS; attempt++ )); do
        if ! fresh_clone; then backoff; continue; fi
        cd "$WORK/deploy"

        if ! git rev-parse --verify --quiet HEAD >/dev/null; then
            echo "No deploy branch yet; nothing to prune."
            return 0
        fi

        removed=0
        for f in hosts/* rev/*; do
            [[ -f "$f" ]] || continue
            name="$(basename "$f")"
            if [[ "$keep" != *" $name "* ]]; then
                echo "Removing stale entry: $f"
                git rm --quiet -- "$f"
                removed=1
            fi
        done

        if (( ! removed )); then
            echo "No stale deploy entries."
            return 0
        fi

        git commit --quiet -m "deploy: remove hosts no longer in the flake"

        if git push --quiet origin HEAD:refs/heads/deploy; then
            return 0
        fi

        echo "Push rejected (attempt ${attempt}/${ATTEMPTS}), retrying..." >&2
        cd "$MAIN_REPO"
        backoff
    done

    echo "ERROR: failed to prune deploy" >&2
    exit 1
}

case "${1:-}" in
    publish)
        [[ $# -eq 3 ]] || { echo "Usage: $0 publish HOST STORE_PATH" >&2; exit 2; }
        publish "$2" "$3"
        ;;
    prune)
        shift
        [[ $# -gt 0 ]] || { echo "ERROR: prune needs at least one host to keep" >&2; exit 2; }
        prune "$@"
        ;;
    *)
        echo "Usage: $0 {publish HOST STORE_PATH | prune HOST...}" >&2
        exit 2
        ;;
esac