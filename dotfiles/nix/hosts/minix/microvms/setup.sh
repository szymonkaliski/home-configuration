#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# copies host config into the VM's /home/szymon
mkdir -p /home/szymon

# claude-code config
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json

# patch .claude.json for VM environment:
# - chromium path differs (nix-profile on host vs system package in VM)
# - trust /workspace so claude doesn't prompt on every boot
node << 'EOF'
const path = "/home/szymon/.claude.json";
const raw = require("fs").readFileSync(path, "utf8");
const patched = raw.replaceAll(
  "/home/szymon/.nix-profile/bin/chromium",
  "/run/current-system/sw/bin/chromium"
);

const config = JSON.parse(patched);
config.projects = config.projects || {};
config.projects["/workspace"] = config.projects["/workspace"] || {};
config.projects["/workspace"].hasTrustDialogAccepted = true;

require("fs").writeFileSync(path, JSON.stringify(config, null, 2));
EOF

# git config (no SSH keys, VMs can pull public repos but not push by design)
cp /mnt/host/gitconfig /home/szymon/.gitconfig
cp /mnt/host/gitignore_global /home/szymon/.gitignore_global

# install/update claude-code via npm (nixpkgs version lags behind)
export NPM_CONFIG_PREFIX=/home/szymon/.npm
npm install -g @anthropic-ai/claude-code@latest

# shell: start in /workspace, alias, etc.
echo 'cd /workspace 2>/dev/null' > /home/szymon/.bash_profile
echo 'export PATH="/home/szymon/.npm/bin:$PATH"' >> /home/szymon/.bash_profile
echo "alias claude-dangerously='claude --dangerously-skip-permissions'" >> /home/szymon/.bash_profile

if [ -f /mnt/host/claude-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /mnt/host/claude-oauth-token)" >> /home/szymon/.bash_profile
fi

# for pushover notifications
if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

chown -R szymon:users /home/szymon

