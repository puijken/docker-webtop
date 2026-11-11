#!/bin/bash
# Deletes old versions of this repo's container image from ghcr.io, keeping the newest KEEP
# builds. A build is a tagged version; everything created more than an hour before the oldest
# kept build goes, tagged or not (that also clears the untagged leftovers of earlier builds).
# The hour of slack keeps any manifests that were pushed together with a kept build.
# Usage: prune-images.sh OWNER PACKAGE KEEP      (needs gh, with GH_TOKEN allowed to delete)
#        prune-images.sh --select KEEP < versions.json   (prints the ids it would delete)
set -euo pipefail

select_ids() {
  python3 -c '
import json, sys
from datetime import datetime, timedelta
keep = int(sys.argv[1])
versions = json.load(sys.stdin)
when = lambda v: datetime.fromisoformat(v["created_at"].replace("Z", "+00:00"))
builds = sorted((v for v in versions if v["metadata"]["container"]["tags"]), key=when, reverse=True)
if len(builds) <= keep:
    sys.exit(0)
cutoff = when(builds[keep - 1]) - timedelta(hours=1)
for v in versions:
    if when(v) < cutoff:
        print(v["id"])
' "$1"
}

if [ "${1:-}" = "--select" ]; then
  select_ids "$2"
  exit 0
fi

owner=$1
package=$2
keep=$3
api="/users/${owner}/packages/container/${package}/versions"
ids=$(gh api --paginate "$api?per_page=100" | python3 -c '
import json, sys
dec, s, out = json.JSONDecoder(), sys.stdin.read().strip(), []
while s:                      # --paginate prints one JSON array per page, back to back
    page, end = dec.raw_decode(s)
    out += page
    s = s[end:].lstrip()
json.dump(out, sys.stdout)' | select_ids "$keep")

if [ -z "$ids" ]; then
  echo "nothing to prune (keeping the newest $keep builds)"
  exit 0
fi
for id in $ids; do
  gh api -X DELETE "$api/$id" > /dev/null
  echo "deleted version $id"
done
