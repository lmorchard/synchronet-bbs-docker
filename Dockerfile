FROM debian:bullseye-slim AS base

ENV TERM=xterm
ENV SBBSDIR=/sbbs
ENV SBBSCTRL=/sbbs/ctrl
ENV SBBSEXEC=/sbbs/exec

ENV USER=root LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

RUN apt-get update \
    && apt-get upgrade -yqq \
    && apt-get install -yqq \
    sudo curl wget ftp openssh-client \
    nano less procps libcap2-bin \
    libarchive13 libarchive-tools \
    zip unzip arj unrar-free p7zip-full lhasa arc \
    libnspr4 jq telnet libffi7 \
    rsh-redone-client locales locales-all \
    mtools dosfstools dos2unix ser2net socat tmux \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create sbbs user/group - passwordless sudo
RUN addgroup --gid 1000 sbbs \
    && adduser --disabled-password --shell /bin/bash --uid 1000 --gid 1000 --gecos '' sbbs \
    && adduser sbbs sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

################################################################################
# Synchronet Build Stage
FROM base AS build

# Build dependencies
RUN apt-get update \
    && apt-get install -yqq \
    build-essential libarchive-dev libffi-dev git \
    libnspr4-dev libncurses5-dev python2 pkgconf \
    mosquitto mosquitto-clients \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /sbbs

# https://wiki.synchro.net/install:nix#tarball_build_method
# RUN wget ftp://vert.synchro.net/Synchronet/sbbs_src.tgz && \
#     wget ftp://vert.synchro.net/Synchronet/sbbs_run.tgz
COPY ./deps/sbbs_run.tgz ./deps/sbbs_src.tgz /tmp
RUN tar -xzf /tmp/sbbs_src.tgz --owner=sbbs --group=sbbs && \
    tar -xzf /tmp/sbbs_run.tgz --owner=sbbs --group=sbbs
RUN cd src/sbbs3 && \
    make RELEASE=1 NO_X=1 symlinks
RUN /sbbs/exec/jsexec update.js

################################################################################
# Runtime Stage
FROM base AS runtime

# Copy Built Synchronet
COPY --from=build --chown=sbbs:sbbs /sbbs /sbbs

WORKDIR /sbbs

USER root

# Ensure we have termcap installed - I forget why but something breaks without this
RUN /usr/bin/tic install/terminfo \
    && cat install/termcap >> /etc/termcap

RUN apt-get update

# Build kermit for file transfers
# ARG KERMIT_SRC_URL=https://www.kermitproject.org/ftp/kermit/pretest/x-20240206.tar.gz
RUN apt-get install -yqq build-essential
# RUN curl $KERMIT_SRC_URL > /tmp/kermit.tar.gz
COPY ./deps/kermit.tar.gz /tmp
RUN mkdir kermit && \
    cd kermit && \
    tar -zxf /tmp/kermit.tar.gz && \
    make linux install && \
    cd .. && \
    rm -rf kermit

# HACK: Install an old known-good version of dosemu to run door games
#ARG DOSEMU_DEB_URL=http://ftp.us.debian.org/debian/pool/contrib/d/dosemu/dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb 
#ARG DOSEMU_DEB_URL=http://archive.debian.org/debian-archive/debian/pool/contrib/d/dosemu/dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb
ARG DOSEMU_DEB=dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb
RUN apt-get install -yqq libasound2 libsdl1.2debian libslang2 libsndfile1 libxxf86vm1 xfonts-utils
RUN mkdir -p /media/CDROM
#RUN wget -nc $DOSEMU_DEB_URL
COPY ./deps/$DOSEMU_DEB /tmp
RUN /usr/bin/dpkg -i /tmp/$DOSEMU_DEB

# Tidy up after all that installing
RUN apt-get -y --purge autoremove build-essential \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# User created in base container
USER sbbs

COPY --chown=sbbs:sbbs ./docker-scripts/ /sbbs/docker-scripts/

# Start SBBS by Default
CMD ["./docker-scripts/start.sh"]

# Declare expected volume mounts
VOLUME [ "/sbbs-data" ]
