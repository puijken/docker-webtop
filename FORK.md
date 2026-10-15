# docker-webtop (fork)

A trimmed, flattened [linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop)
**`fedora-kde`** image with a small set of apps baked in. It is KDE Plasma on Wayland
(`kwin_wayland`), so desktop effects work. Published as `ghcr.io/puijken/docker-webtop:latest`.
Everything in upstream's README still applies: same env vars, same `/config`, same ports.

`main` tracks upstream's `fedora-kde` branch. This file holds the fork's notes so upstream's
README can merge without conflicts.

## Changes from upstream

All of the fork's own build steps are in one block **appended** to upstream's `Dockerfile`, with
no upstream line changed. Upstream merges therefore don't conflict in the `Dockerfile`.

Added:

| App | Package | Source |
|---|---|---|
| VS Code | `code` | packages.microsoft.com |
| Microsoft Edge | `microsoft-edge-stable` | packages.microsoft.com |
| Google Chrome | `google-chrome-stable` | dl.google.com |
| Double Commander (Qt6) | `doublecmd-qt6` | Fedora |
| qimgv (image viewer) | `qimgv` | Fedora |
| mpv (video player) | `mpv` + `ffmpeg-libs` | Fedora + RPM Fusion |

mpv decodes on the iGPU through `/etc/mpv/mpv.conf` (`hwdec=auto-safe`). Fedora's mpv has
hardware decoding off by default.

Fedora's own ffmpeg (`*-free`) has no H.264/HEVC. `ffmpeg-libs` from RPM Fusion replaces it;
the base image already enables RPM Fusion and ships the Intel/Mesa VA-API drivers.

Removed again after upstream installs them: `chromium`, `kwrite`, `papirus-icon-theme`,
`plasma-discover`, `plasma-discover-packagekit`. `dnf remove` skips packages that aren't
installed, so the list can't break when upstream drops one.

Removed from the base, because a desktop never uses them:
- the Docker engine (`moby-engine`, `containerd`, `runc`, CLI, compose). It only starts in a
  privileged container anyway;
- the compilers and build tools (`gcc`, `gcc-c++`, `cmake`, Rust);
- `glibc-all-langpacks` (replaced by `en` + `nl`);
- translations other than en/nl, the browsers' other language packs, and `/usr/share/doc`;
- `libva-intel-driver`, the legacy i965 VA-API driver. linuxserver's `init-video` sets
  `LIBVA_DRIVER_NAME=i965` whenever that driver loads. Without it, libva uses `iHD`
  (`intel-media-driver`, from the base), which encoded about twice as fast and gave sharper text
  on a UHD 630.

The base's `python3-*` and `perl-*` packages are marked as user-installed first, so the removal
can't take them as "unused dependencies". Selkies' venv uses system site-packages, which rpm
can't see. Dropping `python3-cffi` once took the stream down. The smoke test imports Selkies to
catch this.

**Flattened.** `flatten.sh LAYERED TARGET` turns the built image into one layer (`FROM scratch` +
`COPY --from`). Without that, removed files would still be in the base image's layers. It copies
the runtime config (`ENV`, `ENTRYPOINT`, `EXPOSE`, `VOLUME`, ...) from the layered image
mechanically, so upstream config changes flow through. The smoke test checks that the two match.

Chrome, Edge and VS Code start through `/usr/local/bin/wrapped-{chrome,edge,code}`. The wrappers
add `--no-sandbox` (the Chromium sandbox can't work in an unprivileged container, same as
upstream's `wrapped-chromium`) and the Wayland flag. Every `.desktop` file pointing at the real
binaries is rewritten to use them.

linuxserver's GitHub workflows are removed, because they would run unguarded here. `Jenkinsfile`,
`package_versions.txt`, `wrapped-chromium` and the rest of `.github` are left untouched on
purpose, so merges stay clean. They are inert here. Only amd64 is built.

## Pulling in upstream

This is automatic. The weekly CI run executes `sync-upstream.sh` before building:
1. It merges `upstream/fedora-kde`.
2. It deletes linuxserver's workflows again, whether upstream changed one (conflict) or added a
   new one.
3. CI builds, flattens and smoke-tests the result.

Only if all of that passes does CI push both the merge commit and `:latest`. Otherwise `main` and
`:latest` stay on the last good state, and the failed run sends an email.

What can still need a hand:
- A real conflict, which means upstream appended to the very end of the `Dockerfile`. It's rare.
  Run `./sync-upstream.sh` locally, resolve, push.
- A new Fedora release (every ~6 months) renaming a package the fork block installs. The build
  fails, so fix the name.

To sync by hand, run `./sync-upstream.sh` then `git push`.

## CI

`build.yml` builds on a push to `main`, on manual dispatch, and **weekly**. The weekly and manual
runs merge upstream first. The weekly run also keeps the browsers and VS Code current, since they
only update when the image is rebuilt. Each run builds, then runs `flatten.sh`, then
`smoke_test.sh IMAGE LAYERED_IMAGE` before pushing `:latest`. The smoke test checks:
- the apps are present and every launcher goes through a wrapper;
- the trimmed packages are gone, and the RPM Fusion ffmpeg is installed;
- the locale and file capabilities are intact;
- Selkies imports;
- the runtime config matches the layered image.

`pr-validate.yml` runs the same on pull requests.
