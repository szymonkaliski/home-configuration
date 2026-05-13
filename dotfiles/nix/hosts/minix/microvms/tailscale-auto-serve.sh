#!/usr/bin/env bash

# auto-expose user-owned listening ports via `tailscale serve`

set -u

STATE_DIR=/run/tailscale-auto-serve
mkdir -p "$STATE_DIR"
rm -f "$STATE_DIR"/*
tailscale serve reset 2>/dev/null || true

# match loopback-reachable bindings (127/8, ::1, 0.0.0.0, *, [::])
# owned by uid >= 1000 - skips sshd, tailscaled, systemd-resolved, etc.
list_ports() {
  ss -tlnHe | awk '
    {
      ap = $4
      n = split(ap, parts, ":")
      port = parts[n]
      addr = parts[1]
      for (i = 2; i < n; i++) addr = addr ":" parts[i]
      sub(/%.*/, "", addr); gsub(/[][]/, "", addr)
      if (!(addr == "" || addr == "*" || addr == "0.0.0.0" \
            || addr == "::" || addr == "::1" || addr ~ /^127\./)) next
      uid = -1
      for (i = 1; i <= NF; i++) if ($i ~ /^uid:/) { sub(/^uid:/, "", $i); uid = $i + 0 }
      if (uid >= 1000) print port
    }' | sort -u
}

do_sync() {
  local want have port
  want=$(list_ports || true)
  have=$(find "$STATE_DIR" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | sort -u || true)

  for port in $want; do
    if ! grep -qx "$port" <<<"$have"; then
      if tailscale serve --bg --https="$port" "http://127.0.0.1:$port"; then
        touch "$STATE_DIR/$port"
        echo "served :$port" >&2
      fi
    fi
  done

  for port in $have; do
    if ! grep -qx "$port" <<<"$want"; then
      tailscale serve --https="$port" off 2>/dev/null || true
      rm -f "$STATE_DIR/$port"
      echo "unserved :$port" >&2
    fi
  done
}

do_sync

bpftrace -B line -e '
  tracepoint:sock:inet_sock_set_state
  /args->newstate == 10 || args->oldstate == 10/
  { printf("sync\n"); }
' | while IFS= read -r _; do
  # debounce: drain events arriving within 500ms before syncing
  while IFS= read -t 0.5 -r _; do :; done
  do_sync
done
