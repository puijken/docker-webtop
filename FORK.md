# docker-webtop (fork)

A trimmed, flattened [linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop)
**`fedora-kde`** image with a small set of apps baked in. It is KDE Plasma on Wayland
(`kwin_wayland`), so desktop effects work. Published as `ghcr.io/puijken/docker-webtop:latest`,
and each build also under a dated tag (`:YYYY-MM-DD`, UTC) to roll back to.
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

Chrome, Edge and VS Code start through `/usr/local/bin/wrapped-{chrome,edge,code}`, which add
the Wayland flag and decide about the sandbox (next section). Every `.desktop` file pointing at
the real binaries is rewritten to use them.

## Browser sandbox

Chromium's sandbox needs unprivileged user namespaces. Docker's default seccomp profile denies
them, so upstream's wrappers pass `--no-sandbox`, and by default so do this fork's. Then nothing
stands between a malicious page and the rest of the desktop.

The fork's wrappers check at every start whether the container may create user namespaces
(`unshare --user --pid --net --fork true`). If it may, they leave `--no-sandbox` out and Chrome,
Edge and VS Code run sandboxed. To allow it, start the container with a seccomp profile that is
Docker's default plus one rule (allow `clone`, `unshare` and `setns` without `CAP_SYS_ADMIN`):

```bash
./seccomp-profile.sh > seccomp-userns.json          # for this host's Docker version
```

```yaml
    security_opt:
      - seccomp=./seccomp-userns.json
```

The trade-off: every process in the container can then create user namespaces, which exposes
more of the kernel to it. Regenerate the profile after a Docker upgrade, since it is a copy of
that version's default. Without the profile the image behaves as before.

Tested with the profile: all three start without `--no-sandbox`, and their renderers run in
their own PID namespace. CI only covers the fallback, because its runner uses the default
profile.

linuxserver's GitHub workflows are removed, because they would run unguarded here. `Jenkinsfile`,
`package_versions.txt`, `wrapped-chromium` and the rest of `.github` are left untouched on
purpose, so merges stay clean. They are inert here. Only amd64 is built.

## Pulling in upstream

This is automatic. The weekly CI run executes `sync-upstream.sh` before building:
1. It merges `upstream/fedora-kde`.
2. It deletes linuxserver's workflows again, whether upstream changed one (conflict) or added a
   new one.
3. CI builds, flattens and smoke-tests the result.

Only if all of that passes does CI push both the merge commit and the image (`:latest` and the
dated tag). Otherwise `main` and `:latest` stay on the last good state, and the failed run sends
an email.

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
- the runtime config matches the layered image;
- **the desktop starts.** The image is run without a GPU (software rendering, which is all a CI
  runner has). `kwin_wayland`, `plasmashell` and the web port must be up within 90 s and still up
  15 s later, and Chrome and Edge must start through their wrappers. The other checks only prove
  files exist; this one catches an upstream change to the start scripts that would leave a black
  screen.

Runs don't overlap (`concurrency`), so a push build and the weekly run can't publish out of
order.

**Rolling back:** point the container at a dated tag from before the bad build, for example
`ghcr.io/puijken/docker-webtop:2026-01-05`. The last step of each run (`prune-images.sh`) keeps
the newest three builds on ghcr.io and deletes older versions, including untagged ones.

`pr-validate.yml` runs the same on pull requests.
