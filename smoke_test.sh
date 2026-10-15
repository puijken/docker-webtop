#!/bin/bash
# Checks on a built image: the added apps are installed, their launchers go through the
# --no-sandbox wrappers, the trimmed packages are gone, and the flattened image kept the layered
# image's runtime config. Usage: smoke_test.sh IMAGE LAYERED_IMAGE
set -euo pipefail

cfg='{{json .Config.Env}} {{json .Config.Entrypoint}} {{json .Config.Cmd}} {{.Config.WorkingDir}} {{json .Config.ExposedPorts}} {{json .Config.Volumes}} {{.Config.User}}'
if [ "$(docker inspect -f "$cfg" "$1")" != "$(docker inspect -f "$cfg" "$2")" ]; then
  echo "runtime config differs from the layered image (flatten.sh bug?):"
  diff <(docker inspect -f "$cfg" "$2" | tr ' ,' '\n\n') <(docker inspect -f "$cfg" "$1" | tr ' ,' '\n\n') || true
  exit 1
fi

docker run --rm --entrypoint /bin/bash "$1" -c '
  set -euo pipefail
  for bin in code google-chrome-stable microsoft-edge-stable qimgv mpv doublecmd-qt6 \
             wl-copy wrapped-chrome wrapped-edge wrapped-code kwin_wayland plasmashell; do
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
  rpm -q ffmpeg-libs > /dev/null || { echo "RPM Fusion ffmpeg-libs missing (mkv/HEVC)"; exit 1; }
  locale -a | grep -qi en_US.utf8 || { echo "en_US.UTF-8 locale missing"; exit 1; }
  getcap /usr/libexec/gstreamer-1.0/gst-ptp-helper | grep -q cap_net_bind_service \
    || { echo "file capabilities lost in flatten"; exit 1; }
  # selkies streams the desktop; its venv leans on system python packages a trim can remove.
  /lsiopy/bin/python3 -c "import selkies.__main__" \
    || { echo "selkies does not import"; exit 1; }
  echo "smoke test OK"
'
