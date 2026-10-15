FROM ghcr.io/linuxserver/baseimage-selkies:fedora44

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# title
ENV TITLE="Fedora KDE" \
    PIXELFLUX_WAYLAND=true

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/webtop-logo.png && \
  echo "**** install packages ****" && \
  dnf install -y --setopt=install_weak_deps=False --best \
    aurorae \
    breeze-icon-theme \
    cargo \
    chromium \
    dolphin \
    kde-gtk-config \
    kde-settings-pulseaudio \
    kde-wallpapers \
    kdialog \
    kfind \
    kmenuedit \
    konsole5 \
    kvantum \
    kwrite \
    papirus-icon-theme \
    pipewire \
    plasma-breeze \
    plasma-desktop \
    plasma-discover \
    plasma-discover-packagekit \
    plasma-systemmonitor \
    plasma-workspace-xorg \
    qt5-qtscript \
    wireplumber \
    xdg-desktop-portal \
    xdg-desktop-portal-kde \
    xdg-user-dirs \
    xhost && \
  cargo install \
    wl-clipboard-rs-tools && \
  echo "**** replace wl-clipboard with rust ****" && \
  mv \
    /config/.cargo/bin/wl-* \
    /usr/bin/ && \
  echo "**** application tweaks ****" && \
  sed -i \
    's#^Exec=.*#Exec=/usr/local/bin/wrapped-chromium#g' \
    /usr/share/applications/chromium-browser.desktop && \
  setcap -r \
    /usr/sbin/kwin_wayland && \
  ln -s \
    /usr/sbin/qdbus-qt6 \
    /usr/sbin/qdbus6 && \
  echo "**** kde tweaks ****" && \
  rm -f \
    /etc/xdg/autostart/at-spi-dbus-bus.desktop \
    /etc/xdg/autostart/gmenudbusmenuproxy.desktop \
    /etc/xdg/autostart/polkit-kde-authentication-agent-1.desktop \
    /etc/xdg/autostart/powerdevil.desktop && \
  sed -i \
    -e '/^InputMethod/d' \
    -e '/^VirtualKeyboardEnabled/d' \
    /usr/share/kde-settings/kde-profile/default/xdg/kwinrc && \
  echo "**** cleanup ****" && \
  dnf autoremove -y && \
  dnf clean all && \
  rm -rf \
    /config/.cargo \
    /config/.cache \
    /tmp/*

# add local files
COPY /root /
COPY --from=ghcr.io/linuxserver/selkies-layers:amd64-fedora44-kwin / /

# ports and volumes
EXPOSE 3001
VOLUME /config

# ---- fork (see FORK.md) ----
# Everything the fork changes is in this appended block, so upstream merges stay conflict-free.
# The image is flattened afterwards by flatten.sh, which is what makes the removals below count.
RUN \
  echo "**** fork: vendor repos ****" && \
  rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
  rpm --import https://dl.google.com/linux/linux_signing_key.pub && \
  printf '[vscode]\nname=VS Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
    > /etc/yum.repos.d/vscode.repo && \
  printf '[microsoft-edge]\nname=Microsoft Edge\nbaseurl=https://packages.microsoft.com/yumrepos/edge\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
    > /etc/yum.repos.d/microsoft-edge.repo && \
  printf '[google-chrome]\nname=Google Chrome\nbaseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://dl.google.com/linux/linux_signing_key.pub\n' \
    > /etc/yum.repos.d/google-chrome.repo && \
  echo "**** fork: apps (ffmpeg-libs from RPM Fusion: Fedora's own ffmpeg lacks H.264/HEVC) ****" && \
  dnf install -y --setopt=install_weak_deps=False --best --allowerasing \
    code \
    doublecmd-qt6 \
    ffmpeg-libs \
    google-chrome-stable \
    microsoft-edge-stable \
    mpv \
    qimgv && \
  echo "**** fork: launchers through the --no-sandbox wrappers ****" && \
  grep -l /usr/bin/google-chrome-stable /usr/share/applications/*.desktop | xargs sed -i \
    's#/usr/bin/google-chrome-stable#/usr/local/bin/wrapped-chrome#g' && \
  grep -l /usr/bin/microsoft-edge-stable /usr/share/applications/*.desktop | xargs sed -i \
    's#/usr/bin/microsoft-edge-stable#/usr/local/bin/wrapped-edge#g' && \
  grep -l /usr/share/code/code /usr/share/applications/*.desktop | xargs sed -i \
    's#/usr/share/code/code#/usr/local/bin/wrapped-code#g' && \
  echo "**** fork: drop what this desktop never uses ****" && \
  echo "**** (keep the base's python/perl: selkies' venv uses system site-packages, which rpm can't see) ****" && \
  rpm -qa --qf '%{NAME}\n' | grep -E '^(python3|perl)' | xargs dnf mark -y user && \
  dnf install -y --setopt=install_weak_deps=False \
    glibc-langpack-en \
    glibc-langpack-nl && \
  dnf remove -y \
    cargo \
    chromium \
    cmake \
    containerd \
    docker-cli \
    docker-compose \
    gcc \
    gcc-c++ \
    glibc-all-langpacks \
    kwrite \
    moby-engine \
    papirus-icon-theme \
    plasma-discover \
    plasma-discover-packagekit \
    runc && \
  dnf autoremove -y && \
  find /usr/share/locale -mindepth 1 -maxdepth 1 \
    ! -name 'en*' ! -name 'nl*' ! -name locale.alias -exec rm -rf {} + && \
  find /opt/google/chrome/locales /opt/microsoft/msedge/locales -name '*.pak' \
    ! -name 'en-US*' ! -name 'en-GB*' ! -name 'nl*' -delete && \
  rm -rf /usr/share/doc/* && \
  dnf clean all && \
  rm -rf \
    /config/.cache \
    /tmp/*
