#!/usr/bin/env bash

export PATH="/Users/szymon/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export SHELL="/bin/zsh"

cd /Users/szymon/Documents/Projects/orchestrator || exit 1

if [ ! -x ./server/target/release/orchestrator-server ] || [ -n "$(find server/Cargo.toml server/Cargo.lock server/src -newer ./server/target/release/orchestrator-server 2>/dev/null)" ]; then
  nix develop "path:$PWD" -c cargo build --release --manifest-path server/Cargo.toml --bin orchestrator-server || exit 1
fi

exec ./server/target/release/orchestrator-server
