#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# copies host config into the VM's /home/szymon
mkdir -p /home/szymon

# set up bash exports
echo "" > /home/szymon/.bash_profile

if [ -f /mnt/host/claude/long-lived-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /mnt/host/claude/long-lived-oauth-token)" >> /home/szymon/.bash_profile
fi

anthropic_model="$(cat /mnt/host/claude/anthropic-model 2>/dev/null)"
if [ -n "$anthropic_model" ]; then
  echo "export ANTHROPIC_MODEL=\"$anthropic_model\"" >> /home/szymon/.bash_profile
fi

# for pushover notifications
if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

# claude-code config
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json

# opencode config
if [ -d /mnt/host/opencode ]; then
  mkdir -p /home/szymon/.config
  cp -rT /mnt/host/opencode /home/szymon/.config/opencode

  if [ -f /home/szymon/.config/opencode/gemini_api_key ]; then
    # opencode's google provider (via @ai-sdk/google) reads GOOGLE_GENERATIVE_AI_API_KEY
    echo "export GOOGLE_GENERATIVE_AI_API_KEY=\"$(cat /home/szymon/.config/opencode/gemini_api_key)\"" >> /home/szymon/.bash_profile
  fi
fi

# gcloud config
if [ -d /mnt/host/gcloud ]; then
  mkdir -p /home/szymon/.config
  cp -rT /mnt/host/gcloud /home/szymon/.config/gcloud
fi

# patch agent configs for the VM environment:
# - claude: inject chromium path for playwright mcp, trust /workspace so it doesn't prompt
# - opencode: auto-approve permissions (the VM is an ephemeral sandbox)
node << 'EOF'
const fs = require("fs");

const vmChromium = "/run/current-system/sw/bin/chromium";

// patch Claude Code
const claudePath = "/home/szymon/.claude.json";
if (fs.existsSync(claudePath)) {
  let raw = fs.readFileSync(claudePath, "utf8");
  raw = raw.replaceAll("/home/szymon/.nix-profile/bin/chromium", vmChromium);

  const config = JSON.parse(raw);
  config.projects = config.projects || {};
  config.projects["/workspace"] = config.projects["/workspace"] || {};
  config.projects["/workspace"].hasTrustDialogAccepted = true;

  fs.writeFileSync(claudePath, JSON.stringify(config, null, 2));
}

// patch opencode: skip permission prompts (opencode has no global skip flag,
// so it must come from config; scoped to the VM copy, not the shared dotfile)
const opencodePath = "/home/szymon/.config/opencode/opencode.json";
if (fs.existsSync(opencodePath)) {
  const config = JSON.parse(fs.readFileSync(opencodePath, "utf8"));
  config.permission = "allow";
  fs.writeFileSync(opencodePath, JSON.stringify(config, null, 2));
}
EOF

# create executable wrappers for claude and opencode
mkdir -p /home/szymon/.bin

# shared tailnet/funnel context, sourced by both wrappers
cat << 'EOF' > /home/szymon/.bin/vm-context.sh
vm_name="$(hostname -s)"
ts_dns="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')"

vm_context="You are running inside an ephemeral, sandboxed NixOS microVM named '${vm_name}'."
if [ -n "$ts_dns" ]; then
  vm_context="${vm_context} Its private Tailscale hostname is '${ts_dns}', reachable only from devices on the same tailnet (not the public internet). Any TCP port you listen on is automatically published on the tailnet at https://${ts_dns}:<PORT> (same port number, TLS-terminated) by a background watcher, so to share a running dev server you just need to listen on a port."
  vm_context="${vm_context} That serve is PRIVATE to the tailnet. To make a port public (reachable by anyone, not just the tailnet) when asked to funnel it, run 'tailscale funnel --bg --https=443 http://127.0.0.1:<PORT>'; it then lives at https://${ts_dns}/ . Stop with 'tailscale funnel --https=443 off'. Only one port can be funnelled at a time."
fi
EOF

cat << 'EOF' > /home/szymon/.bin/claude
#!/bin/sh
export PATH="/home/szymon/.npm/bin:/run/current-system/sw/bin:$PATH"
. /home/szymon/.bin/vm-context.sh
exec npx -y @anthropic-ai/claude-code@latest --dangerously-skip-permissions --effort ultracode --append-system-prompt "$vm_context" "$@"
EOF
chmod +x /home/szymon/.bin/claude

cat << 'EOF' > /home/szymon/.bin/opencode
#!/bin/sh
export PATH="/home/szymon/.npm/bin:/run/current-system/sw/bin:$PATH"
. /home/szymon/.bin/vm-context.sh
mkdir -p /home/szymon/.config/opencode
echo "$vm_context" > /home/szymon/.config/opencode/AGENTS.md
exec npx -y opencode-ai@latest "$@"
EOF
chmod +x /home/szymon/.bin/opencode

chown -R szymon:users /home/szymon

