FROM debian:bullseye-slim

ENV TERM=xterm
ENV SBBSDIR=/sbbs
ENV SBBSCTRL=/sbbs/ctrl
ENV SBBSEXEC=/sbbs/exec
ENV USER=root LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install dependencies - mixing runtime & build, TODO: separate for a cleaner image
RUN apt-get update && apt-get upgrade -yqq && apt-get install -yqq \
    sudo curl wget ftp openssh-client nano less procps libcap2-bin \
    libarchive13 libarchive-tools zip unzip arj unrar-free p7zip-full lhasa arc \
    libnspr4 jq telnet libffi7 rsh-redone-client locales locales-all \
    mtools dosfstools dos2unix ser2net socat tmux \
    mosquitto mosquitto-clients mosquitto-dev libmosquitto-dev libmosquitto1 \
    build-essential libarchive-dev libffi-dev git \
    libnspr4-dev libncurses5-dev python2 pkgconf

# Create sbbs user/group - passwordless sudo
RUN addgroup --gid 1000 sbbs && \
    adduser --disabled-password --shell /bin/bash --uid 1000 --gid 1000 --gecos '' sbbs && \
    adduser sbbs sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

WORKDIR /sbbs

# Build Kermit for file transfers, before synchronet since it's likely to change less often
COPY ./deps/kermit.tar.gz /tmp
RUN mkdir /tmp/kermit && \
    cd /tmp/kermit && \
    tar -zxf /tmp/kermit.tar.gz && \
    make linux install && \
    cd / && \
    rm -rf /tmp/kermit /tmp/kermit.tar.gz

# Install DOSEMU for door games, also less often to change vs synchronet
ARG DOSEMU_DEB=dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb
COPY ./deps/$DOSEMU_DEB /tmp
RUN apt-get install -yqq libasound2 libsdl1.2debian libslang2 libsndfile1 libxxf86vm1 xfonts-utils && \
    /usr/bin/dpkg -i /tmp/$DOSEMU_DEB && \
    mkdir -p /media/CDROM

# Build Synchronet
# https://wiki.synchro.net/install:nix#tarball_build_method
COPY ./deps/sbbs_run.tgz ./deps/sbbs_src.tgz /tmp
RUN tar -xzf /tmp/sbbs_src.tgz --owner=sbbs --group=sbbs && \
    tar -xzf /tmp/sbbs_run.tgz --owner=sbbs --group=sbbs && \
    cd src/sbbs3 && make RELEASE=1 NO_X=1 symlinks && \
    /sbbs/exec/jsexec update.js

# Install termcap
RUN /usr/bin/tic install/terminfo && cat install/termcap >> /etc/termcap

# Clean up build dependencies
RUN apt-get -y --purge autoremove build-essential git pkgconf && \
    apt-get -y autoremove && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# This can be rather slow - thinking about going to a multi-stage build
# so we can COPY --chown sbbs:sbbs instead
RUN chown sbbs:sbbs -R /sbbs

COPY --chown=sbbs:sbbs ./docker-scripts/ /sbbs/docker-scripts/

USER sbbs

CMD ["./docker-scripts/start.sh"]
VOLUME [ "/data" ]
