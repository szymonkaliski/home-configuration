#!/usr/bin/env bash

# runs at VM boot via systemd (setup-user.service)
# copies host config into the VM's /home/szymon
mkdir -p /home/szymon

# claude-code config
cp -rT /mnt/host/claude /home/szymon/.claude
cp /mnt/host/claude.json /home/szymon/.claude.json

# gemini-cli config
cp -rT /mnt/host/gemini /home/szymon/.gemini

# patch .claude.json and .gemini/settings.json for VM environment:
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

// patch Gemini CLI settings
const geminiPath = "/home/szymon/.gemini/settings.json";
if (fs.existsSync(geminiPath)) {
  const config = JSON.parse(fs.readFileSync(geminiPath, "utf8"));
  if (config.mcpServers?.playwright) {
    config.mcpServers.playwright.args = [
      "@playwright/mcp@latest",
      "--isolated",
      "--executable-path",
      vmChromium,
    ];
    config.mcpServers.playwright.env = { PLAYWRIGHT_BROWSERS_PATH: "" };
  }
  fs.writeFileSync(geminiPath, JSON.stringify(config, null, 2));
}

// trust /workspace in Gemini CLI
fs.writeFileSync(
  "/home/szymon/.gemini/trustedFolders.json",
  JSON.stringify({ "/workspace": "TRUST_FOLDER" }, null, 2)
);
EOF

echo "" > /home/szymon/.bash_profile
if [ -f /mnt/host/claude/long-lived-oauth-token ]; then
  echo "export CLAUDE_CODE_OAUTH_TOKEN=$(cat /mnt/host/claude/long-lived-oauth-token)" >> /home/szymon/.bash_profile
  echo 'export ANTHROPIC_MODEL="opus[1m]"' >> /home/szymon/.bash_profile
fi

if [ -f /mnt/host/gemini-api-key ]; then
  echo "export GEMINI_API_KEY=$(cat /mnt/host/gemini-api-key)" >> /home/szymon/.bash_profile
fi

# for pushover notifications
if [ -f /mnt/host/pushoverrc ]; then
  cp /mnt/host/pushoverrc /home/szymon/.pushoverrc
fi

# create executable wrappers for claude and gemini
mkdir -p /home/szymon/.local/bin
cat << 'EOF' > /home/szymon/.local/bin/claude
#!/bin/sh
export PATH="/home/szymon/.npm/bin:$PATH"
exec npx -y @anthropic-ai/claude-code@latest --dangerously-skip-permissions "$@"
EOF

cat << 'EOF' > /home/szymon/.local/bin/gemini
#!/bin/sh
export PATH="/home/szymon/.npm/bin:$PATH"
exec npx -y @google/gemini-cli@latest --yolo "$@"
EOF
chmod +x /home/szymon/.local/bin/claude /home/szymon/.local/bin/gemini

chown -R szymon:users /home/szymon

