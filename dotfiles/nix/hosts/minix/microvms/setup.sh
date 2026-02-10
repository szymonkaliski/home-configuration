#!/usr/bin/env bash
mkdir -p /home/szymon
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json
cp -rT /mnt/host/ssh /home/szymon/.ssh
cp /mnt/host/gitconfig /home/szymon/.gitconfig
cp /mnt/host/gitignore_global /home/szymon/.gitignore_global
echo 'cd /workspace 2>/dev/null' > /home/szymon/.bash_profile
chown -R szymon:users /home/szymon
