#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# copies host config into the VM's /home/szymon
mkdir -p /home/szymon

# claude Code config
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json

# git config (no SSH keys, VMs can pull public repos but not push)
cp /mnt/host/gitconfig /home/szymon/.gitconfig
cp /mnt/host/gitignore_global /home/szymon/.gitignore_global

# shell: start in /workspace, aliases
echo 'cd /workspace 2>/dev/null' > /home/szymon/.bash_profile
echo "alias claude-dangerously='claude --dangerously-skip-permissions'" >> /home/szymon/.bash_profile

if [ -f /mnt/host/claude-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /mnt/host/claude-oauth-token)" >> /home/szymon/.bash_profile
fi

if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

chown -R szymon:users /home/szymon
