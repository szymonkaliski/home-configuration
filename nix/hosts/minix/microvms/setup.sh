#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# bin/microvm pre-stages the agent configs into /home/szymon before boot;
# this script derives env exports from them, merges AGENTS.md, patches
# configs for the VM, and touches /mnt/data/.setup-done when finished

set -eu

mkdir -p /home/szymon

# set up bash exports
echo "" > /home/szymon/.bash_profile

if [ -f /home/szymon/.claude/long-lived-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /home/szymon/.claude/long-lived-oauth-token)" >> /home/szymon/.bash_profile
fi

# the setup-token has inference-only scope, so claude code can't fetch the
# plan tier and would gate fable behind usage credits (claude-code#79360);
# CLAUDE_CODE_SUBSCRIPTION_TYPE tells it the plan directly
subscription_type="$(cat /home/szymon/.claude/subscription-type 2>/dev/null || true)"
if [ -n "$subscription_type" ]; then
  echo "export CLAUDE_CODE_SUBSCRIPTION_TYPE=\"$subscription_type\"" >> /home/szymon/.bash_profile
fi

anthropic_model="$(cat /home/szymon/.claude/anthropic-model 2>/dev/null || true)"
if [ -n "$anthropic_model" ]; then
  echo "export ANTHROPIC_MODEL=\"$anthropic_model\"" >> /home/szymon/.bash_profile
fi

# for pushover notifications
if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

if [ -f /home/szymon/.config/opencode/gemini_api_key ]; then
  # opencode's google provider (via @ai-sdk/google) reads GOOGLE_GENERATIVE_AI_API_KEY
  echo "export GOOGLE_GENERATIVE_AI_API_KEY=\"$(cat /home/szymon/.config/opencode/gemini_api_key)\"" >> /home/szymon/.bash_profile
fi

# single cross-harness instructions file: VM context + the shared AGENTS.md,
# with each harness's path symlinked at it, mirroring how the host symlinks
# dotfiles/agents/AGENTS.md
vm_name="$(uname -n)"
ts_suffix="$(cat /mnt/host/ts-magicdns-suffix 2>/dev/null || true)"

vm_context="You are running inside an ephemeral, sandboxed NixOS microVM named '${vm_name}'."
if [ -n "$ts_suffix" ]; then
  ts_dns="${vm_name}.${ts_suffix}"
  vm_context="${vm_context} Its private Tailscale hostname is '${ts_dns}', reachable only from devices on the same tailnet (not the public internet). Any TCP port you listen on is automatically published on the tailnet at https://${ts_dns}:<PORT> (same port number, TLS-terminated) by a background watcher, so to share a running dev server you just need to listen on a port."
  vm_context="${vm_context} That serve is PRIVATE to the tailnet. To make a port public (reachable by anyone, not just the tailnet) when asked to funnel it, run 'tailscale funnel --bg --https=443 http://127.0.0.1:<PORT>'; it then lives at https://${ts_dns}/ . Stop with 'tailscale funnel --https=443 off'. Only one port can be funnelled at a time."
fi

mkdir -p /home/szymon/.config/agents /home/szymon/.claude /home/szymon/.config/opencode /home/szymon/.gemini/config
{
  echo "$vm_context"
  if [ -f /mnt/host/AGENTS.md ]; then
    echo ""
    cat /mnt/host/AGENTS.md
  fi
} > /home/szymon/.config/agents/AGENTS.md

ln -sf /home/szymon/.config/agents/AGENTS.md /home/szymon/.claude/CLAUDE.md
ln -sf /home/szymon/.config/agents/AGENTS.md /home/szymon/.config/opencode/AGENTS.md
ln -sf /home/szymon/.config/agents/AGENTS.md /home/szymon/.gemini/config/AGENTS.md

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
// also inject chromium path for playwright mcp
const opencodePath = "/home/szymon/.config/opencode/opencode.json";
if (fs.existsSync(opencodePath)) {
  let raw = fs.readFileSync(opencodePath, "utf8");
  raw = raw.replaceAll("/home/szymon/.nix-profile/bin/chromium", vmChromium);

  const config = JSON.parse(raw);
  config.permission = "allow";
  fs.writeFileSync(opencodePath, JSON.stringify(config, null, 2));
}
EOF

# create executable wrappers for the agent CLIs
mkdir -p /home/szymon/.bin

cat << 'EOF' > /home/szymon/.bin/claude
#!/bin/sh
export PATH="/home/szymon/.npm/bin:/run/current-system/sw/bin:$PATH"
exec npx -y @anthropic-ai/claude-code@latest --dangerously-skip-permissions --effort ultracode "$@"
EOF
chmod +x /home/szymon/.bin/claude

cat << 'EOF' > /home/szymon/.bin/opencode
#!/bin/sh
export PATH="/home/szymon/.npm/bin:/run/current-system/sw/bin:$PATH"
exec npx -y opencode-ai@latest "$@"
EOF
chmod +x /home/szymon/.bin/opencode

cat << 'EOF' > /home/szymon/.bin/agy
#!/bin/sh
export PATH="/home/szymon/.npm/bin:/run/current-system/sw/bin:$PATH"
exec /run/current-system/sw/bin/agy --dangerously-skip-permissions "$@"
EOF
chmod +x /home/szymon/.bin/agy

chown -R szymon:users /home/szymon

touch /mnt/data/.setup-done
