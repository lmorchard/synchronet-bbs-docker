#!/bin/bash
set -e

VERSION="${1:-}"  # Optional version parameter (e.g., "320d")

mkdir -p deps
cd deps

# Download Synchronet sources
if [ -n "$VERSION" ]; then
    echo "Downloading Synchronet stable version: $VERSION"
    wget -nc ftp://vert.synchro.net/Synchronet/ssrc${VERSION}.tgz -O sbbs_src.tgz
    wget -nc ftp://vert.synchro.net/Synchronet/srun${VERSION}.tgz -O sbbs_run.tgz
else
    echo "Downloading Synchronet latest development version"
    wget -nc ftp://vert.synchro.net/Synchronet/sbbs_src.tgz
    wget -nc ftp://vert.synchro.net/Synchronet/sbbs_run.tgz
fi

# Download other dependencies (version-independent)
wget -nc http://archive.debian.org/debian-archive/debian/pool/contrib/d/dosemu/dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb

# Kermit - always overwrite to ensure latest
curl https://www.kermitproject.org/ftp/kermit/pretest/x-20240206.tar.gz > kermit.tar.gz

echo "Dependencies downloaded successfully"
