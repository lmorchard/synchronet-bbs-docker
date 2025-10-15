#!/bin/bash
mkdir -p deps
cd deps
wget -nc ftp://vert.synchro.net/Synchronet/sbbs_src.tgz
wget -nc ftp://vert.synchro.net/Synchronet/sbbs_run.tgz
wget -nc http://archive.debian.org/debian-archive/debian/pool/contrib/d/dosemu/dosemu_1.4.0.7+20130105+b028d3f-2+b1_amd64.deb
curl https://www.kermitproject.org/ftp/kermit/pretest/x-20240206.tar.gz > kermit.tar.gz
