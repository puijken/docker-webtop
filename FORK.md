# docker-webtop (fork)

A trimmed, flattened [linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop)
**`fedora-kde`** image with a small set of apps baked in. It is KDE Plasma on Wayland
(`kwin_wayland`), so desktop effects work. Published as `ghcr.io/puijken/docker-webtop:latest`.
Everything in upstream's README still applies: same env vars, same `/config`, same ports.

`main` tracks upstream's `fedora-kde` branch. This file holds the fork's notes so upstream's
README can merge without conflicts.

## Changes from upstream

All of the fork's own build steps are in one block at the end of the `Dockerfile`. Upstream's
part only loses a few package lines.

Added:

| App | Package | Source |
|---|---|---|
| VS Code | `code` | packages.microsoft.com |
| Microsoft Edge | `microsoft-edge-stable` | packages.microsoft.com |
| Google Chrome | `google-chrome-stable` | dl.google.com |
| Double Commander (Qt6) | `doublecmd-qt6` | Fedora |
| qimgv (image viewer) | `qimgv` | Fedora |
| mpv (video player) | `mpv` + `ffmpeg-libs` | Fedora + RPM Fusion |

Fedora's own ffmpeg (`*-free`) has no H.264/HEVC. `ffmpeg-libs` from RPM Fusion replaces it;
the base image already enables RPM Fusion and ships the Intel/Mesa VA-API drivers.

Removed from upstream's list: `chromium`, `kwrite`, `papirus-icon-theme`, `plasma-discover`,
`plasma-discover-packagekit`.

Removed from the base, because a desktop never uses them:
- the Docker engine (`moby-engine`, `containerd`, `runc`, CLI, compose). It only starts in a
  privileged container anyway;
- the compilers and build tools (`gcc`, `gcc-c++`, `cmake`, Rust);
- `glibc-all-langpacks` (replaced by `en` + `nl`);
- translations other than en/nl, the browsers' other language packs, and `/usr/share/doc`.

**Flattened.** The final stage is `FROM scratch` + `COPY --from=build / /`. Without it, removed
files would still be in the base image's layers. The runtime config (`ENV`, `ENTRYPOINT`,
`EXPOSE`, `VOLUME`) is restated by hand. `smoke_test.sh` compares it with the unflattened
`build` stage and fails on any drift. When it fails after an upstream merge, copy the new values
into the `ENV` block.

Chrome, Edge and VS Code start through `/usr/local/bin/wrapped-{chrome,edge,code}`. The wrappers
add `--no-sandbox` (the Chromium sandbox can't work in an unprivileged container, same as
upstream's `wrapped-chromium`) and the Wayland flag. Every `.desktop` file pointing at the real
binaries is rewritten to use them.

linuxserver's GitHub workflows are removed, because they would run unguarded here. `Jenkinsfile`,
`package_versions.txt`, `wrapped-chromium` and the rest of `.github` are left untouched on
purpose, so merges stay clean. They are inert here. Only amd64 is built.

## Pulling in upstream

```sh
git fetch upstream
git merge upstream/fedora-kde
git push            # triggers the build
```

Conflicts can only happen in the `Dockerfile` (upstream's package list) or in a removed workflow.
For a workflow, resolve with `git rm`. When linuxserver moves to a new Fedora release, the base
tag in `FROM` changes with the merge. Check that the fork block's packages still exist there.

## CI

`build.yml` builds on a push to `main`, on manual dispatch, and **weekly**. The weekly run keeps
the browsers and VS Code current, since they only update when the image is rebuilt. Before
pushing `:latest`, it runs `smoke_test.sh IMAGE BUILD_STAGE_IMAGE`, which checks:
- the apps are present and every launcher goes through a wrapper;
- the trimmed packages are gone, and the RPM Fusion ffmpeg is installed;
- the locale and file capabilities are intact;
- the runtime config matches the build stage.

`pr-validate.yml` runs the same on pull requests.
