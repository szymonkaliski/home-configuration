#!/usr/bin/env bash

ts() { while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done; }
exec > >(ts) 2>&1

pushd ~/Library/CloudStorage/Dropbox/Wiki/ || exit 1

git diff-index --quiet HEAD -- || (
  git add -A .
  AFFECTED=$(git status --porcelain | cut -c 4- | awk 'ORS=", "' | sed 's/..$//')
  git commit -m "Affected files: $AFFECTED"
)
