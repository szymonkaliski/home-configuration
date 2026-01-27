#!/usr/bin/env bash

date

pushd ~/Library/CloudStorage/Dropbox/Wiki/ || exit 1

git diff-index --quiet HEAD -- || (
  git add -A .
  AFFECTED=$(git status --porcelain | cut -c 4- | awk 'ORS=", "' | sed 's/..$//')
  git commit -m "Affected files: $AFFECTED"
)

