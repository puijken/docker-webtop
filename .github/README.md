# docker-webtop

A personal fork of [linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop): a full
Linux desktop (KDE Plasma) running in a container and used through a web browser.

Image: `ghcr.io/puijken/docker-webtop:latest`

## Why a fork

linuxserver's webtop images are general-purpose by design. They ship a broad set of packages so
that they work for as many people as possible, and they leave customisation to runtime add-ons.

This fork is tailored to one setup instead:

- **The tools I use are part of the image.** They're available from the first start, survive
  every update, and don't depend on runtime installs or compatibility layers.
- **It's leaner.** What a browser-based desktop never needs is removed, and the image is
  flattened so those removals actually make it smaller.
- **Some defaults are tuned for the hardware it runs on.**

## Staying close to upstream

The fork follows upstream's `fedora-kde` branch and changes as little as possible:

- All of its own build steps sit in one block appended to upstream's `Dockerfile`. No upstream
  line is edited, so upstream changes merge cleanly.
- A weekly CI run merges upstream, builds and tests the image, and publishes it only if every check
  passes. If anything fails, the previous image stays in place.

The details (what changes and why, how syncing and testing work) are in [FORK.md](../FORK.md).
The usage documentation in [README.md](../README.md) is upstream's, and still applies: same
settings, same ports, same `/config`.

## Credits and license

All the real work is linuxserver.io's: the images, the Selkies streaming stack and the desktop
integration. This fork only rearranges the packages on top. It is not affiliated with
linuxserver.io, and its issues are not theirs, so please don't report problems with this image to
them.

Licensed under GPL-3.0, like upstream. See [LICENSE](../LICENSE).
