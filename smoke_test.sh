#!/bin/bash
# Checks on a built image: the added apps are installed, their launchers go through the
# --no-sandbox wrappers, the trimmed packages are gone, the flattened image kept the layered
# image's runtime config, and the desktop actually starts. Usage: smoke_test.sh IMAGE LAYERED_IMAGE
set -euo pipefail

cfg='{{json .Config.Env}} {{json .Config.Entrypoint}} {{json .Config.Cmd}} {{.Config.WorkingDir}} {{json .Config.ExposedPorts}} {{json .Config.Volumes}} {{.Config.User}}'
if [ "$(docker inspect -f "$cfg" "$1")" != "$(docker inspect -f "$cfg" "$2")" ]; then
  echo "runtime config differs from the layered image (flatten.sh bug?):"
  diff <(docker inspect -f "$cfg" "$2" | tr ' ,' '\n\n') <(docker inspect -f "$cfg" "$1" | tr ' ,' '\n\n') || true
  exit 1
fi

docker run --rm --entrypoint /bin/bash "$1" -c '
  set -euo pipefail
  # ss: an on-demand watchdog checks connections with it; without it, idle detection breaks.
  for bin in code google-chrome-stable microsoft-edge-stable qimgv mpv \
             wl-copy wrapped-chrome wrapped-edge wrapped-code kwin_wayland plasmashell \
             ss; do
    command -v "$bin" > /dev/null || { echo "missing: $bin"; exit 1; }
  done
  if grep -l -E "/usr/bin/(google-chrome|microsoft-edge)-stable|/usr/share/code/code" /usr/share/applications/*.desktop; then
    echo "launcher(s) above bypass the wrappers"; exit 1
  fi
  grep -q wrapped-chrome /usr/share/applications/google-chrome.desktop
  grep -q wrapped-edge /usr/share/applications/microsoft-edge.desktop
  grep -q wrapped-code /usr/share/applications/com.microsoft.VSCode.desktop
  for bin in cargo gcc dockerd containerd cmake chromium-browser plasma-discover; do
    if command -v "$bin" > /dev/null; then echo "still installed: $bin"; exit 1; fi
  done
  if rpm -q libva-intel-driver > /dev/null; then echo "i965 driver back: init-video would force it over iHD"; exit 1; fi
  grep -q "^hwdec=" /etc/mpv/mpv.conf || { echo "mpv hardware decoding not configured"; exit 1; }
  rpm -q ffmpeg-libs > /dev/null || { echo "RPM Fusion ffmpeg-libs missing (mkv/HEVC)"; exit 1; }
  locale -a | grep -qi en_US.utf8 || { echo "en_US.UTF-8 locale missing"; exit 1; }
  getcap /usr/libexec/gstreamer-1.0/gst-ptp-helper | grep -q cap_net_bind_service \
    || { echo "file capabilities lost in flatten"; exit 1; }
  # selkies streams the desktop; its venv leans on system python packages a trim can remove.
  /lsiopy/bin/python3 -c "import selkies.__main__" \
    || { echo "selkies does not import"; exit 1; }
  echo "static checks OK"
'

# Boot test: start the image the way a user would and wait for the desktop. The checks above only
# prove that files exist; an upstream change to the start scripts would pass them and still leave
# a black screen. No GPU is passed in, so this runs the software-rendering path, which is also
# what a CI runner has.
name="webtop-smoke-$$"
docker run -d --rm --name "$name" --shm-size=1g "$1" > /dev/null
trap 'docker rm -f "$name" > /dev/null 2>&1 || true' EXIT

desktop_up() {
  docker exec "$name" bash -c '
    pgrep -x kwin_wayland > /dev/null && pgrep -x plasmashell > /dev/null &&
    [ "$(curl -sk -o /dev/null -w "%{http_code}" --max-time 3 https://localhost:3001/)" = 200 ]
  ' 2> /dev/null
}

boot_failed() {
  echo "boot test: $1"
  docker logs --tail 60 "$name" 2>&1 || true
  exit 1
}

booted=""
for _ in $(seq 1 45); do
  if desktop_up; then booted=1; break; fi
  sleep 2
done
[ -n "$booted" ] || boot_failed "no desktop (kwin_wayland, plasmashell, HTTP 200 on :3001) within 90 s"

# Still there a little later: catches a compositor or shell that starts and then crash-loops.
sleep 15
desktop_up || boot_failed "the desktop came up but did not stay up for 15 s"

echo "smoke test OK"
