#!/bin/bash
set -ex

cd /sbbs
./docker-scripts/link-sbbs-data.sh
(cd /doorparty/doorparty-connector/ && ./doorparty-connector &)
exec /sbbs/exec/sbbs "$@" || exit $?
