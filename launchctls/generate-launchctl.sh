#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

LAUNCHCTL_SCRIPTS_PATH="$(pwd)/scripts"

TEMPLATE=$1
OUTPUT="${TEMPLATE%.tmpl}"

sed "s|LAUNCHCTL_SCRIPTS_PATH|$LAUNCHCTL_SCRIPTS_PATH|g" $TEMPLATE > $OUTPUT
