#!/usr/bin/env node
'use strict';

// Pre-configures the claude-hud statusline and disables the extra
// --dangerously-skip-permissions confirmation prompt, baked into the image
// at /home/node/.claude so a fresh named volume (mounted there by
// devcontainer.json) is seeded with this content on first container start.
//
// Usage: node configure-claude-settings.js <node-runtime-path>

const fs = require('fs');
const path = require('path');
const os = require('os');

const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const settingsPath = path.join(claudeDir, 'settings.json');
const runtimePath = process.argv[2];

if (!runtimePath) {
  console.error('Usage: configure-claude-settings.js <node-runtime-path>');
  process.exit(1);
}

fs.mkdirSync(claudeDir, { recursive: true });

let json = {};
if (fs.existsSync(settingsPath)) {
  json = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
}

// The whole script is later wrapped in an outer bash -c '...' (see below),
// so any single quote here would otherwise close that outer string early.
// Q is the standard bash trick for embedding a literal single quote inside
// a single-quoted string: close the quote, emit it via a double-quoted
// segment, then reopen the quote.
const Q = '\'"\'"\'';

const statuslineScript = [
  'cols=${COLUMNS:-}',
  `case "$cols" in ""|*[!0-9]*) cols=$(stty size </dev/tty 2>/dev/null | awk ${Q}{print $2}${Q});; esac`,
  'case "$cols" in ""|*[!0-9]*) cols=120;; esac',
  'export COLUMNS=$(( cols > 4 ? cols - 4 : 1 ))',
  `plugin_dir=$(ls -d "\${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ ${Q}{ print $(NF-1) "\\t" $(0) }${Q} | grep -E ${Q}^[0-9]+\\.[0-9]+\\.[0-9]+[[:space:]]${Q} | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)`,
  `exec "${runtimePath}" "\${plugin_dir}dist/index.js"`,
].join('; ');

json.statusLine = {
  type: 'command',
  command: `bash -c '${statuslineScript}'`,
};
json.skipDangerousModePermissionPrompt = true;

fs.writeFileSync(settingsPath, JSON.stringify(json, null, 2) + '\n');
console.log(`Wrote statusLine + skipDangerousModePermissionPrompt to ${settingsPath}`);
