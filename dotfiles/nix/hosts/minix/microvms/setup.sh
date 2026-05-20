#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# copies host config into the VM's /home/szymon
mkdir -p /home/szymon

# set up bash exports
echo "" > /home/szymon/.bash_profile
if [ -f /mnt/host/claude/long-lived-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /mnt/host/claude/long-lived-oauth-token)" >> /home/szymon/.bash_profile
  echo 'export ANTHROPIC_MODEL="opus[1m]"' >> /home/szymon/.bash_profile
fi

# for pushover notifications
if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

# claude-code config
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json

# gcloud config
if [ -d /mnt/host/gcloud ]; then
  mkdir -p /home/szymon/.config
  cp -rT /mnt/host/gcloud /home/szymon/.config/gcloud
fi

# patch .claude.json for VM environment:
# - inject chromium path for playwright mcp (system package in VM)
# - trust /workspace so claude doesn't prompt on every boot
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
EOF

# create executable wrapper for claude
mkdir -p /home/szymon/.bin

cat << 'EOF' > /home/szymon/.bin/claude
#!/bin/sh
export PATH="/home/szymon/.npm/bin:$PATH"
exec npx -y @anthropic-ai/claude-code@latest --dangerously-skip-permissions "$@"
EOF
chmod +x /home/szymon/.bin/claude

chown -R szymon:users /home/szymon

