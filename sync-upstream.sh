#!/bin/bash
# Merges linuxserver's fedora-kde branch into the current branch. linuxserver's own workflows,
# which this fork deletes, are deleted again automatically, whether upstream changed one
# (conflict) or added a new one. Any other conflict aborts the merge and exits non-zero.
set -euo pipefail
UPSTREAM_URL=${UPSTREAM_URL:-https://github.com/linuxserver/docker-webtop}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-fedora-kde}
OUR_WORKFLOWS="build.yml pr-validate.yml dependabot-auto-merge.yml"

git remote get-url upstream > /dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch -q upstream "$UPSTREAM_BRANCH"

if ! git merge -q --no-edit -m "Merge upstream $UPSTREAM_BRANCH" FETCH_HEAD; then
  conflicts=$(git diff --name-only --diff-filter=U)
  if echo "$conflicts" | grep -v -q '^\.github/workflows/'; then
    echo "conflicts outside .github/workflows, resolve by hand (see FORK.md):"
    echo "$conflicts"
    git merge --abort
    exit 1
  fi
  echo "$conflicts" | xargs git rm -q
  git commit -q --no-edit
fi

for f in .github/workflows/*; do
  case " $OUR_WORKFLOWS " in
    *" $(basename "$f") "*) ;;
    *) git rm -q "$f" ;;
  esac
done
if ! git diff --cached --quiet; then
  git commit -q -m "Drop upstream workflows re-added by the merge"
fi

git log -1 --format='now at %h %s'
