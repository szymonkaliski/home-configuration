#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

LAUNCHCTL_SCRIPTS_PATH="$(pwd)/scripts"

if [ -z "$1" ]; then
  echo "Usage: $0 TEMPLATE_FILE.tmpl"
  exit 1
fi

TEMPLATE=$1
OUTPUT="${TEMPLATE%.tmpl}"

if [ -z "$OUTPUT" ]; then
  echo "Could not generate the output file name"
  exit 1
fi

sed "s|LAUNCHCTL_SCRIPTS_PATH|$LAUNCHCTL_SCRIPTS_PATH|g" "$TEMPLATE" > "$OUTPUT"

