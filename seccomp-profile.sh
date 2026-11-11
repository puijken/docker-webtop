#!/bin/bash
# Prints a seccomp profile that lets this image's browsers and VS Code run with their own
# sandbox: Docker's default profile for the given Docker version, plus one rule that allows
# clone, unshare and setns without CAP_SYS_ADMIN (unprivileged user namespaces). See FORK.md.
# Usage: seccomp-profile.sh [DOCKER_VERSION] > seccomp-userns.json
#        (default: the version of this host's Docker daemon). Regenerate after a Docker upgrade.
set -euo pipefail
version=${1:-$(docker version --format '{{.Server.Version}}')}

# Where Docker's default profile lives has moved between releases; take the first that exists.
for path in \
  "docker-v${version}/vendor/github.com/moby/profiles/seccomp/default.json" \
  "v${version}/vendor/github.com/moby/profiles/seccomp/default.json" \
  "v${version}/profiles/seccomp/default.json"; do
  if profile=$(curl -fsSL "https://raw.githubusercontent.com/moby/moby/${path}" 2> /dev/null); then
    break
  fi
  profile=""
done
[ -n "$profile" ] || { echo "no default seccomp profile found for Docker ${version}" >&2; exit 1; }

python3 -c '
import json, sys
p = json.load(sys.stdin)
p["syscalls"].append({
    "names": ["clone", "unshare", "setns"],
    "action": "SCMP_ACT_ALLOW",
    "comment": "docker-webtop: unprivileged user namespaces, for the Chromium sandbox",
})
json.dump(p, sys.stdout, indent=2)
print()
' <<< "$profile"
