#!/bin/bash
# Flattens an image into a single layer, so files removed in later layers stop taking space, and
# copies its runtime config (ENV, ENTRYPOINT, CMD, EXPOSE, VOLUME, WORKDIR, USER, LABEL) across
# mechanically. Nothing is restated by hand, so upstream config changes flow through.
# Usage: flatten.sh SOURCE_IMAGE TARGET_TAG
set -euo pipefail
src=$1
dst=$2

docker inspect "$src" | python3 -c '
import json, sys

src = sys.argv[1]
c = json.load(sys.stdin)[0]["Config"]

def q(v):
    # Dockerfile double-quoted value: keep $, \ and " literal.
    return "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"").replace("$", "\\$") + "\""

print("FROM scratch")
print(f"COPY --from={src} / /")
for e in c.get("Env") or []:
    k, v = e.split("=", 1)
    print(f"ENV {k}={q(v)}")
for k, v in sorted((c.get("Labels") or {}).items()):
    print(f"LABEL {q(k)}={q(v)}")
for p in sorted(c.get("ExposedPorts") or {}):
    print(f"EXPOSE {p}")
for v in sorted(c.get("Volumes") or {}):
    print(f"VOLUME {json.dumps([v])}")
if c.get("WorkingDir"):
    print("WORKDIR " + c["WorkingDir"])
if c.get("User"):
    print("USER " + c["User"])
if c.get("Entrypoint"):
    print("ENTRYPOINT " + json.dumps(c["Entrypoint"]))
if c.get("Cmd"):
    print("CMD " + json.dumps(c["Cmd"]))
' "$src" | docker build -q -t "$dst" - > /dev/null

echo "flattened $src -> $dst"
