#!/bin/bash
set -ex

cd /sbbs
./docker-scripts/link-sbbs-data.sh
exec /sbbs/exec/sbbs "$@" || exit $?
