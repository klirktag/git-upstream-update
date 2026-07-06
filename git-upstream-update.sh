#!/usr/bin/env bash
#
# git-upstream-update.sh
#
# GitHub-specific helper that syncs your fork's default branch with the
# upstream repository it was forked from.
#
# What it does:
#   1. Uses `gh` to detect whether the current repo is a fork.
#   2. If it is, the parent repo is treated as the upstream.
#   3. Ensures a git remote named `upstream` points at that parent.
#   4. Checks out the default branch (master/main/whatever it is).
#   5. Fetches upstream and fast-forwards the local default branch to it.
#   6. Pushes the updated branch to `origin` (never force-pushed).
#
# Requirements: git, gh (authenticated: `gh auth status`).
#
# After updating, the default branch is pushed to `origin` (never force-pushed).
# If origin has diverged from upstream the push is refused and the script stops
# with a warning rather than overwriting anything.
#
# Usage:
#   git-upstream-update.sh [-f] [--remote NAME]
#
#   -f, --force     Force-push to origin, overwriting the diverged branch.
#                   Off by default; use only when you intend to discard
#                   origin's divergent commits.
#   --remote NAME   Name to use for the upstream remote (default: upstream).

set -euo pipefail

UPSTREAM_REMOTE="upstream"
FORCE=0

die() {
    echo "error: $*" >&2
    exit 1
}

info() {
    echo ">> $*" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force)
            FORCE=1
            shift
            ;;
        --remote)
            [[ $# -ge 2 ]] || die "--remote requires an argument"
            UPSTREAM_REMOTE="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

command -v git >/dev/null 2>&1 || die "git is not installed"
command -v gh  >/dev/null 2>&1 || die "gh (GitHub CLI) is not installed"
command -v jq  >/dev/null 2>&1 || die "jq is not installed"

# Make sure we're inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git repository"

# Query GitHub for fork status, parent, and the parent's default branch.
# `gh repo view` operates on the repo of the current directory.
info "querying GitHub for repository metadata..."
repo_json=$(gh repo view \
    --json isFork,parent,defaultBranchRef,nameWithOwner 2>/dev/null) \
    || die "could not read repo metadata from gh (is the remote a GitHub repo, and are you authenticated? try 'gh auth status')"

is_fork=$(printf '%s' "$repo_json" | jq -r '.isFork')
[[ "$is_fork" == "true" ]] \
    || die "this repository is not a fork; there is no upstream to sync from"

# The parent object exposes `owner.login` and `name` (there is no
# `nameWithOwner` field on it), so build the "owner/repo" slug ourselves.
parent_slug=$(printf '%s' "$repo_json" \
    | jq -r 'if .parent and .parent.owner.login and .parent.name
             then "\(.parent.owner.login)/\(.parent.name)" else empty end')
[[ -n "$parent_slug" ]] \
    || die "repo is marked as a fork but no parent was returned by gh"

# Prefer the parent's default branch; fall back to our own if absent.
default_branch=$(printf '%s' "$repo_json" \
    | jq -r '.parent.defaultBranchRef.name // .defaultBranchRef.name // empty')
[[ -n "$default_branch" ]] \
    || die "could not determine the default branch"

info "upstream (parent) repo : $parent_slug"
info "default branch         : $default_branch"

# Ensure the upstream remote exists and points at the parent.
upstream_url="https://github.com/${parent_slug}.git"
if git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
    current_url=$(git remote get-url "$UPSTREAM_REMOTE")
    info "remote '$UPSTREAM_REMOTE' already exists ($current_url)"
else
    info "adding remote '$UPSTREAM_REMOTE' -> $upstream_url"
    git remote add "$UPSTREAM_REMOTE" "$upstream_url"
fi

info "fetching from '$UPSTREAM_REMOTE'..."
git fetch "$UPSTREAM_REMOTE" "$default_branch"

# Refuse to clobber uncommitted work.
if ! git diff --quiet || ! git diff --cached --quiet; then
    die "you have uncommitted changes; commit or stash them before syncing"
fi

info "checking out '$default_branch'..."
git checkout "$default_branch"

# Fast-forward only: this keeps the local branch a clean mirror of upstream.
info "fast-forwarding '$default_branch' to '${UPSTREAM_REMOTE}/${default_branch}'..."
git merge --ff-only "${UPSTREAM_REMOTE}/${default_branch}"

info "done. '$default_branch' is now up to date with $parent_slug."

# Push to origin. By default this is never forced: a non-fast-forward rejection
# means origin has diverged from upstream, and we stop with a warning rather
# than overwrite anything. With -f we force-push and overwrite the divergence.
# The local branch is already updated regardless.
if [[ "$FORCE" -eq 1 ]]; then
    info "force-pushing '$default_branch' to origin..."
    git push --force origin "$default_branch"
    info "force-pushed '$default_branch' to origin."
else
    info "pushing '$default_branch' to origin..."
    if git push origin "$default_branch"; then
        info "pushed '$default_branch' to origin."
    else
        echo "warning: could not push to origin since it has diverged from upstream" >&2
        echo "         re-run with -f to force-push and overwrite the divergence" >&2
        exit 1
    fi
fi
