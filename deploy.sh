#!/usr/bin/env bash
# One-step deploy: verify the build locally, push hakyll, follow the GitHub
# Actions run until the site is live. Pushing hakyll is what deploys; this
# script only adds the checks around it.
#
#   ./deploy.sh        asks before pushing
#   ./deploy.sh --yes  no prompt (agent runs)
set -euo pipefail

readonly REPO="LukasErlenbach/lukaserlenbach.github.io"
readonly GH_USER="LukasErlenbach"
readonly BRANCH="hakyll"
readonly WORKFLOW="deploy.yml"
readonly SITE_URL="https://lukaserlenbach.github.io/"
readonly CRED_KEY="credential.https://github.com.helper"

cd "$(dirname "$0")"

die() { echo "deploy: $*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

assume_yes=false
[ "${1:-}" = "--yes" ] && assume_yes=true

GH="$(command -v gh)" || die "gh CLI not found"
"$GH" auth token --user "$GH_USER" >/dev/null 2>&1 \
  || die "gh has no login for $GH_USER. Run 'gh auth login', then 'gh auth switch' back to your work account."

# The global git config hands github.com credentials to whichever gh account
# is active (the work account). Pin this clone to the private account instead,
# so nobody has to 'gh auth switch'. Lives in .git/config, so a fresh clone
# gets it on its first deploy.
ensure_push_credential() {
  git config --local --get-all "$CRED_KEY" 2>/dev/null | grep -q "user $GH_USER" && return
  git config --local --unset-all "$CRED_KEY" 2>/dev/null || true
  git config --local --add "$CRED_KEY" ""
  git config --local --add "$CRED_KEY" \
    "!f() { test \"\$1\" = get || exit 0; echo username=$GH_USER; echo \"password=\$($GH auth token --user $GH_USER)\"; }; f"
  echo "Configured this clone to push as $GH_USER."
}

step "Preflight"
ensure_push_credential
[ "$(git branch --show-current)" = "$BRANCH" ] || die "not on $BRANCH"
if [ -n "$(git status --porcelain)" ]; then
  git status --short
  die "uncommitted changes. Commit or stash them first: the build check must see exactly what gets pushed."
fi
git fetch --quiet origin "$BRANCH"
git merge-base --is-ancestor "origin/$BRANCH" HEAD \
  || die "origin/$BRANCH has commits you don't have. Run 'git pull --ff-only' first."
if [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$BRANCH")" ]; then
  echo "Nothing to deploy: $BRANCH is already on origin."
  exit 0
fi
echo "Commits to deploy:"
git log --oneline "origin/$BRANCH..HEAD"

step "Build check"
stack build
stack exec WhoNeedsFrameworks-hakyll -- build
stack exec WhoNeedsFrameworks-hakyll -- check --internal-links

if ! $assume_yes; then
  printf '\nPush to %s and deploy live? [y/N] ' "$BRANCH"
  read -r answer
  [ "$answer" = "y" ] || die "aborted, nothing pushed"
fi

step "Push"
git push origin "$BRANCH"
sha="$(git rev-parse HEAD)"

# Scoped to this process; the active gh account stays untouched.
GH_TOKEN="$("$GH" auth token --user "$GH_USER")"
export GH_TOKEN

step "Actions run"
if [ "$("$GH" api "repos/$REPO/actions/caches" --jq '.total_count')" = "0" ]; then
  echo "CI Stack cache is cold: this run compiles every dependency, expect ~20 min."
fi
run_id=""
for _ in $(seq 1 30); do
  run_id="$("$GH" run list -R "$REPO" --workflow "$WORKFLOW" --commit "$sha" \
    --json databaseId --jq '.[0].databaseId // empty')"
  [ -n "$run_id" ] && break
  sleep 2
done
[ -n "$run_id" ] || die "pushed, but no $WORKFLOW run showed up for $sha. Check https://github.com/$REPO/actions"
echo "https://github.com/$REPO/actions/runs/$run_id (Ctrl-C stops watching, not the deploy)"
"$GH" run watch "$run_id" -R "$REPO" --exit-status --interval 15 \
  || die "deploy run failed: '$GH run view $run_id -R $REPO --log-failed'"

step "Live"
echo "$SITE_URL answers $(curl -s -o /dev/null -w '%{http_code}' "$SITE_URL")"
