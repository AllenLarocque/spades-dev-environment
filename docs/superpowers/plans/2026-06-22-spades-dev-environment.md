# spades-dev-environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `AllenLarocque/spades-dev-environment` repo: a public, GPL-3 GitHub template providing a sandboxed devcontainer for SpaDES R development, with Claude Code's `superpowers` and `claude-hud` plugins pre-baked so the environment works immediately on first container start.

**Architecture:** A `.devcontainer/` (Dockerfile + firewall script + devcontainer.json) carried over from an existing sandboxed `claude-code` devcontainer pattern, extended with an R/SpaDES package layer, an extended network allowlist, and a plugin pre-bake step that exploits Docker's volume-seed-from-image behavior. A `resources/spades.ai` git submodule supplies SpaDES domain knowledge to Claude via root `CLAUDE.md`. A gitignored `projects/` folder is the convention for users' own SpaDES project repos.

**Tech Stack:** Docker (devcontainer), bash, Node.js (`node:20` base image, used for a small settings-merge script), R, GitHub Actions (`devcontainers/ci`), git submodules.

## Global Constraints

- Repo: `AllenLarocque/spades-dev-environment`, public, GPL-3.0, marked as a GitHub template repository.
- `projects/` is gitignored except `projects/README.md` and `projects/.gitkeep` — no project code or data belongs in this repo.
- Never commit credentials. The Google service-account key is never baked into the image or committed; it's documented as a manual local mount.
- No `library()`/`install.packages()` calls baked into the image beyond the explicit core list (`Require`, `reproducible`, `SpaDES.core`, `SpaDES.project`, `terra`, `sf`, `data.table`). Everything else (Bioconductor, vegan, etc.) is installed per-project via `Require()` at runtime.
- `CLAUDE_CODE_VERSION` stays `"latest"`.
- The firewall allowlist (`init-firewall.sh`'s `for domain in ...` loop) is a living list — new domains get appended as needed, not redesigned.
- **This implementation session has no Docker daemon available.** Dockerfile and devcontainer.json changes are verified here via static checks only (`bash -n`, `node --check`, JSON/YAML parsing, `grep`). Real build verification happens in Task 7 (CI) or when the repo is opened in an actual Dev Containers environment with Docker.
- The design spec this plan implements: `docs/superpowers/specs/2026-06-22-spades-dev-environment-design.md` (already committed in this repo).

---

### Task 1: Repo scaffolding — gitignore, license, projects/ convention

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `projects/README.md`
- Create: `projects/.gitkeep`

**Interfaces:**
- Consumes: nothing (first content task; repo already has one commit containing the design spec)
- Produces: the `projects/` gitignore convention that Tasks 2–7 reference; `LICENSE` referenced by the root README (Task 2)

- [ ] **Step 1: Write `.gitignore`**

```
# Project content brought in under projects/ — each user's own project repos
projects/*
!projects/README.md
!projects/.gitkeep

# Windows artifacts that show up when data is copied from a Windows machine
desktop.ini
*:Zone.Identifier

# OS junk
.DS_Store

# R session artifacts
.Rhistory
.RData
.Rproj.user/

# Google Drive service-account key — never commit credentials
*gdrive-key.json
```

- [ ] **Step 2: Fetch the canonical GPL-3.0 license text from GitHub's license API and save as `LICENSE`**

Run:
```bash
cd ~/spades-dev-environment
curl -s https://api.github.com/licenses/gpl-3.0 | jq -r .body > LICENSE
```

Expected: `LICENSE` is created, starting with the GNU GPL preamble.

- [ ] **Step 3: Verify the license text looks right**

Run: `head -5 LICENSE && echo --- && wc -l LICENSE`
Expected: first line is blank or the license header text containing `GNU GENERAL PUBLIC LICENSE`, and the file has several hundred lines (the full GPL-3.0 text, not a stub).

- [ ] **Step 4: Write `projects/README.md`**

```markdown
# projects/

This is where your own SpaDES project repos live. This directory is gitignored
(except this file) — nothing you put here becomes part of the
`spades-dev-environment` template.

## Adding a project

Clone your project repo directly into this folder:

```bash
cd projects
git clone https://github.com/<you>/<your-project>.git
```

Or, if you want this template repo to track which version of your project
you're using, add it as a git submodule instead:

```bash
cd projects
git submodule add https://github.com/<you>/<your-project>.git
```

Once it's there, open it in the same VS Code window as this devcontainer —
your project gets the R/SpaDES environment, the network sandbox, and the
`superpowers`/`claude-hud` Claude Code plugins for free, with no per-project
setup.
```

- [ ] **Step 5: Create `projects/.gitkeep`**

Run: `touch ~/spades-dev-environment/projects/.gitkeep`

- [ ] **Step 6: Verify all four files exist with the right content**

Run:
```bash
cd ~/spades-dev-environment
test -f .gitignore && test -f LICENSE && test -f projects/README.md && test -f projects/.gitkeep && echo "all files present"
grep -q "GNU GENERAL PUBLIC LICENSE" LICENSE && echo "license text ok"
grep -q "^projects/\*$" .gitignore && echo "gitignore ok"
```
Expected: `all files present`, `license text ok`, `gitignore ok` — all three printed, no errors.

- [ ] **Step 7: Commit**

```bash
cd ~/spades-dev-environment
git add .gitignore LICENSE projects/README.md projects/.gitkeep
git commit -m "Add repo scaffolding: gitignore, GPL-3 license, projects/ convention"
```

---

### Task 2: Root README.md

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: `LICENSE` (Task 1), `projects/README.md` (Task 1), `resources/spades.ai/SPADES-AI.md` (Task 3 — written about here but doesn't need to exist yet for this task's own verification)
- Produces: the canonical usage documentation other tasks don't need to duplicate

- [ ] **Step 1: Write `README.md`**

```markdown
# spades-dev-environment

A sandboxed, reproducible [devcontainer](https://containers.dev/) for developing
[SpaDES](https://spades.predictiveecology.org) ecological and bioinformatics
workflows with [Claude Code](https://claude.com/claude-code) — safe to run with
`--dangerously-skip-permissions` because all outbound network traffic is locked
down to an explicit allowlist.

## Quick start

1. Click **Use this template** on GitHub (or
   `gh repo create my-project --template AllenLarocque/spades-dev-environment --public --clone`).
2. Open the resulting repo in VS Code with the
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   installed.
3. Run **Dev Containers: Reopen in Container**. First build takes a few minutes.
4. Once it's up, `claude` is ready to go — the `superpowers` and `claude-hud`
   plugins are already installed, and the HUD statusline is already configured.
   No setup commands needed.

## Adding your project

See [`projects/README.md`](projects/README.md). Short version: clone or
`git submodule add` your own SpaDES project repo into `projects/` — it's
gitignored here, so your project's code and data never become part of this
template.

## What's pre-installed

- System libraries for `terra`/`sf`/GDAL-based SpaDES workflows (e.g. LandR
  Biomass): GDAL, GEOS, PROJ, udunits2, and friends.
- Core R/SpaDES packages, installed system-wide: `Require`, `reproducible`,
  `SpaDES.core`, `SpaDES.project`, `terra`, `sf`, `data.table`.
- Claude Code plugins `superpowers` and `claude-hud`, pre-installed and
  pre-configured during the image build.

Everything else — `phyloseq`, `DESeq2`, `vegan`, `iNEXT`, `indicspecies`,
Quarto, etc. — is **not** pre-installed. Pull these in per-project with
`Require()` at runtime (never `library()` or `install.packages()` directly —
see [`resources/spades.ai/SPADES-AI.md`](resources/spades.ai/SPADES-AI.md)
for why).

## Network sandbox

`.devcontainer/init-firewall.sh` runs on container start and locks outbound
traffic to an explicit allowlist: GitHub, CRAN (`cloud.r-project.org`),
Bioconductor, Posit Package Manager, r-universe, npm, the Anthropic API, and a
few VS Code/telemetry domains. Everything else is rejected.

If a project needs a new domain (another r-universe org, a data host, etc.),
add it to the `for domain in ...` loop in `init-firewall.sh` — this list is
expected to grow over time, not a one-time decision.

## Optional: Google Drive access

For downloading shared/private datasets via R's `googledrive` package (which
SpaDES `prepInputs()` delegates to for Drive URLs), the firewall allows the
relevant Google domains, but you still need credentials. Use a Google Cloud
**service account** (not interactive browser login — there's no browser in
this container):

1. Create a service account and download its JSON key.
2. Save it on your host machine, *outside* this repo, e.g.
   `~/.config/spades-dev-environment/gdrive-key.json`.
3. Share the relevant Drive files/folders with the service account's email
   address.
4. Add a mount for the key to `.devcontainer/devcontainer.json`'s `mounts`
   array (not included by default, since most users won't need it):
   ```json
   "source=${localEnv:HOME}/.config/spades-dev-environment/gdrive-key.json,target=/home/node/.config/gdrive-key.json,type=bind"
   ```
   Then rebuild the container. The key is never committed or baked into the
   image.

## Contributing

This is a public template meant to be shared and improved by other SpaDES
users. To propose a change to the Dockerfile or firewall script, open a PR —
`.github/workflows/build-devcontainer.yml` builds the image and runs a smoke
check on every PR, so a broken environment gets caught before merge.

## License

GPL-3.0 — see [`LICENSE`](LICENSE).
```

- [ ] **Step 2: Verify required sections are present**

Run:
```bash
cd ~/spades-dev-environment
for heading in "## Quick start" "## Adding your project" "## What's pre-installed" "## Network sandbox" "## Optional: Google Drive access" "## Contributing" "## License"; do
  grep -qF "$heading" README.md && echo "OK: $heading" || echo "MISSING: $heading"
done
```
Expected: every line printed as `OK: ...`, none as `MISSING: ...`.

- [ ] **Step 3: Commit**

```bash
cd ~/spades-dev-environment
git add README.md
git commit -m "Add README with quick start, network sandbox, and Drive access docs"
```

---

### Task 3: resources/spades.ai submodule + root CLAUDE.md

**Files:**
- Create: `resources/spades.ai` (git submodule, source `https://github.com/AllenLarocque/spades.ai.git`)
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: nothing new
- Produces: `resources/spades.ai/SPADES-AI.md`, imported by `CLAUDE.md` and linked from `README.md` (Task 2)

- [ ] **Step 1: Add the submodule**

```bash
cd ~/spades-dev-environment
git submodule add https://github.com/AllenLarocque/spades.ai.git resources/spades.ai
git submodule update --init --recursive
```

- [ ] **Step 2: Verify the submodule is populated**

Run:
```bash
cd ~/spades-dev-environment
test -f resources/spades.ai/SPADES-AI.md && echo "submodule content present"
git submodule status
```
Expected: `submodule content present`, and `git submodule status` lists `resources/spades.ai` with a commit hash (no leading `-`, which would mean uninitialized).

- [ ] **Step 3: Write `CLAUDE.md`**

```markdown
# spades-dev-environment

This is a SpaDES devcontainer template. `projects/` holds user-added SpaDES
project repos (gitignored). See `projects/README.md` for the convention.

@resources/spades.ai/SPADES-AI.md
```

- [ ] **Step 4: Verify**

Run:
```bash
cd ~/spades-dev-environment
test -f CLAUDE.md && grep -q "@resources/spades.ai/SPADES-AI.md" CLAUDE.md && echo "CLAUDE.md ok"
```
Expected: `CLAUDE.md ok`.

- [ ] **Step 5: Commit**

```bash
cd ~/spades-dev-environment
git add .gitmodules resources/spades.ai CLAUDE.md
git commit -m "Add spades.ai as a submodule under resources/, wire into CLAUDE.md"
```

---

### Task 4: Dockerfile — base R/SpaDES layer

**Files:**
- Create: `.devcontainer/Dockerfile`

**Interfaces:**
- Consumes: nothing new (carries over the R/SpaDES layer already present in the `anthropics/claude-code` clone at `/workspace/.devcontainer/Dockerfile`, which is the validated starting point per the design spec's migration plan)
- Produces: the base image that Task 5 inserts the plugin pre-bake into, between the `npm install -g @anthropic-ai/claude-code` line and the firewall `COPY`

- [ ] **Step 1: Write `.devcontainer/Dockerfile`**

```dockerfile
FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install R and the geospatial system libraries needed by terra/sf/GDAL-based
# SpaDES workflows (e.g. LandR Biomass)
RUN apt-get update && apt-get install -y --no-install-recommends \
  r-base \
  r-base-dev \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libgdal-dev \
  gdal-bin \
  libgeos-dev \
  libproj-dev \
  libudunits2-dev \
  libsqlite3-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install the core SpaDES R package ecosystem (system-wide library, so it's
# available to the node user without a per-project install step)
RUN Rscript -e "install.packages(c('Require', 'reproducible', 'SpaDES.core', 'SpaDES.project', 'terra', 'sf', 'data.table'), repos = 'https://cloud.r-project.org', Ncpus = parallel::detectCores())"

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  sudo dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
```

- [ ] **Step 2: Verify structurally (no Docker daemon in this sandbox — see Global Constraints)**

Run:
```bash
cd ~/spades-dev-environment
grep -q "^FROM node:20$" .devcontainer/Dockerfile && echo "base image ok"
grep -q "SpaDES.core" .devcontainer/Dockerfile && echo "SpaDES packages ok"
grep -q "libgdal-dev" .devcontainer/Dockerfile && echo "geospatial libs ok"
grep -q "npm install -g @anthropic-ai/claude-code" .devcontainer/Dockerfile && echo "claude install ok"
```
Expected: all four `... ok` lines printed.

- [ ] **Step 3: Commit**

```bash
cd ~/spades-dev-environment
git add .devcontainer/Dockerfile
git commit -m "Add base Dockerfile: R/SpaDES system + package layer"
```

---

### Task 5: Plugin pre-bake (superpowers, claude-hud, HUD statusline)

**Files:**
- Create: `.devcontainer/bake-plugins.sh`
- Create: `.devcontainer/configure-claude-settings.js`
- Modify: `.devcontainer/Dockerfile` (insert a `COPY`+`RUN` block right after the `RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}` line from Task 4, while still `USER node`, before the `COPY init-firewall.sh` line)

**Interfaces:**
- Consumes: `.devcontainer/Dockerfile` from Task 4 (exact insertion point: immediately after the `claude-code` npm install `RUN`, before the blank line + `# Copy and set up firewall script` comment)
- Produces: `/home/node/.claude/settings.json` inside the image with `statusLine` and `skipDangerousModePermissionPrompt: true` set, and `superpowers`/`claude-hud` installed under `/home/node/.claude/plugins/` — this is what gets seeded into the `claude-code-config-${devcontainerId}` named volume on first container start (see `devcontainer.json`, Task 6)

- [ ] **Step 1: Write `.devcontainer/bake-plugins.sh`**

```bash
#!/bin/bash
set -euo pipefail

claude plugin marketplace add obra/superpowers-marketplace
claude plugin marketplace add jarrodwatts/claude-hud
claude plugin install superpowers@superpowers-marketplace
claude plugin install claude-hud@claude-hud
```

- [ ] **Step 2: Verify shell syntax**

Run: `bash -n ~/spades-dev-environment/.devcontainer/bake-plugins.sh`
Expected: no output, exit code 0.

- [ ] **Step 3: Write `.devcontainer/configure-claude-settings.js`**

```javascript
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

const statuslineScript = [
  'cols=${COLUMNS:-}',
  'case "$cols" in ""|*[!0-9]*) cols=$(stty size </dev/tty 2>/dev/null | awk \'{print $2}\');; esac',
  'case "$cols" in ""|*[!0-9]*) cols=120;; esac',
  'export COLUMNS=$(( cols > 4 ? cols - 4 : 1 ))',
  'plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ \'{ print $(NF-1) "\\t" $(0) }\' | grep -E \'^[0-9]+\\.[0-9]+\\.[0-9]+[[:space:]]\' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)',
  `exec "${runtimePath}" "\${plugin_dir}dist/index.js"`,
].join('; ');

json.statusLine = {
  type: 'command',
  command: `bash -c '${statuslineScript}'`,
};
json.skipDangerousModePermissionPrompt = true;

fs.writeFileSync(settingsPath, JSON.stringify(json, null, 2) + '\n');
console.log(`Wrote statusLine + skipDangerousModePermissionPrompt to ${settingsPath}`);
```

- [ ] **Step 4: Verify JS syntax**

Run: `node --check ~/spades-dev-environment/.devcontainer/configure-claude-settings.js`
Expected: no output, exit code 0.

- [ ] **Step 5: Functional test against a scratch settings directory**

Run:
```bash
rm -rf /tmp/fake-claude-dir
mkdir -p /tmp/fake-claude-dir
CLAUDE_CONFIG_DIR=/tmp/fake-claude-dir node ~/spades-dev-environment/.devcontainer/configure-claude-settings.js /usr/local/bin/node
test -f /tmp/fake-claude-dir/settings.json && echo "settings.json written"
node -e "
const d = require('/tmp/fake-claude-dir/settings.json');
if (d.skipDangerousModePermissionPrompt !== true) throw new Error('skipDangerousModePermissionPrompt not set');
if (!d.statusLine || d.statusLine.type !== 'command' || !d.statusLine.command.includes('/usr/local/bin/node')) throw new Error('statusLine not set correctly');
console.log('functional test passed');
"
rm -rf /tmp/fake-claude-dir
```
Expected: `settings.json written` then `functional test passed`, no errors thrown.

- [ ] **Step 6: Insert the plugin pre-bake into the Dockerfile**

Use the Edit tool on `.devcontainer/Dockerfile` (from Task 4):

old_string:
```
# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}


# Copy and set up firewall script
```

new_string:
```
# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Pre-install Claude Code plugins so every fresh instance of this template
# has them ready immediately. This relies on Docker seeding a fresh named
# volume from the image's directory contents on first mount: devcontainer.json
# mounts a volume at /home/node/.claude, and whatever exists there in the
# image becomes that volume's initial content on first container start.
COPY bake-plugins.sh configure-claude-settings.js /tmp/
RUN chmod +x /tmp/bake-plugins.sh && \
  /tmp/bake-plugins.sh && \
  node /tmp/configure-claude-settings.js /usr/local/bin/node && \
  rm /tmp/bake-plugins.sh /tmp/configure-claude-settings.js


# Copy and set up firewall script
```

- [ ] **Step 7: Verify the insertion**

Run:
```bash
cd ~/spades-dev-environment
grep -q "bake-plugins.sh" .devcontainer/Dockerfile && echo "plugin bake wired into Dockerfile"
grep -n "RUN npm install -g @anthropic-ai/claude-code" .devcontainer/Dockerfile
grep -n "COPY bake-plugins.sh" .devcontainer/Dockerfile
grep -n "COPY init-firewall.sh" .devcontainer/Dockerfile
```
Expected: `plugin bake wired into Dockerfile`, and the three line numbers printed in ascending order (claude-code install, then the plugin bake COPY, then the firewall COPY) — confirming the insertion landed between the right two existing lines.

- [ ] **Step 8: Commit**

```bash
cd ~/spades-dev-environment
git add .devcontainer/bake-plugins.sh .devcontainer/configure-claude-settings.js .devcontainer/Dockerfile
git commit -m "Pre-bake superpowers + claude-hud plugins and HUD statusline into the image"
```

---

### Task 6: Firewall allowlist + devcontainer.json

**Files:**
- Create: `.devcontainer/init-firewall.sh`
- Create: `.devcontainer/devcontainer.json`

**Interfaces:**
- Consumes: `.devcontainer/Dockerfile` (Task 5) — `devcontainer.json`'s `build.dockerfile` field points at it; `init-firewall.sh` is `COPY`'d into the image by the Dockerfile and invoked via `devcontainer.json`'s `postStartCommand`
- Produces: the complete `.devcontainer/` directory, ready for a real container build (Task 7 CI, or a user's local Dev Containers build)

- [ ] **Step 1: Write `.devcontainer/init-firewall.sh`**

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, and pipeline failures
IFS=$'\n\t'       # Stricter word splitting

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# First allow DNS and localhost before any restrictions
# Allow outbound DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
# Allow inbound DNS responses
iptables -A INPUT -p udp --sport 53 -j ACCEPT
# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
# Allow inbound SSH responses
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# Allow localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Create ipset with CIDR support
ipset create allowed-domains hash:net

# Fetch GitHub meta information and aggregate + add their IP ranges
echo "Fetching GitHub IP ranges..."
gh_ranges=$(curl -s https://api.github.com/meta)
if [ -z "$gh_ranges" ]; then
    echo "ERROR: Failed to fetch GitHub IP ranges"
    exit 1
fi

if ! echo "$gh_ranges" | jq -e '.web and .api and .git' >/dev/null; then
    echo "ERROR: GitHub API response missing required fields"
    exit 1
fi

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
       echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr"
done < <(echo "$gh_ranges" | jq -r '(.web + .api + .git)[]' | aggregate -q)

# Resolve and add other allowed domains
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "sentry.io" \
    "statsig.com" \
    "marketplace.visualstudio.com" \
    "vscode.blob.core.windows.net" \
    "update.code.visualstudio.com" \
    "deb.debian.org" \
    "cloud.r-project.org" \
    "bioconductor.org" \
    "packagemanager.posit.co" \
    "predictiveecology.r-universe.dev" \
    "raw.githubusercontent.com" \
    "codeload.github.com" \
    "objects.githubusercontent.com" \
    "drive.google.com" \
    "drive.usercontent.google.com" \
    "www.googleapis.com" \
    "oauth2.googleapis.com" \
    "accounts.google.com"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "ERROR: Failed to resolve $domain"
        exit 1
    fi
    
    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "ERROR: Invalid IP from DNS for $domain: $ip"
            exit 1
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
done

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

# Set up remaining iptables rules
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT

# Set default policies to DROP first
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# First allow established connections for already approved traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Then allow only specific outbound traffic to allowed domains
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Explicitly REJECT all other outbound traffic for immediate feedback
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - was able to reach https://example.com"
    exit 1
else
    echo "Firewall verification passed - unable to reach https://example.com as expected"
fi

# Verify GitHub API access
if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
else
    echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi
```

- [ ] **Step 2: Verify shell syntax and the new domains are present**

Run:
```bash
cd ~/spades-dev-environment
bash -n .devcontainer/init-firewall.sh && echo "syntax ok"
for d in bioconductor.org packagemanager.posit.co predictiveecology.r-universe.dev raw.githubusercontent.com codeload.github.com objects.githubusercontent.com drive.google.com drive.usercontent.google.com www.googleapis.com oauth2.googleapis.com accounts.google.com; do
  grep -q "\"$d\"" .devcontainer/init-firewall.sh && echo "OK: $d" || echo "MISSING: $d"
done
```
Expected: `syntax ok`, then eleven `OK: ...` lines, no `MISSING: ...` lines.

- [ ] **Step 3: Write `.devcontainer/devcontainer.json`**

```json
{
  "name": "SpaDES Dev Environment",
  "build": {
    "dockerfile": "Dockerfile",
    "args": {
      "TZ": "${localEnv:TZ:America/Los_Angeles}",
      "CLAUDE_CODE_VERSION": "latest",
      "GIT_DELTA_VERSION": "0.18.2",
      "ZSH_IN_DOCKER_VERSION": "1.2.0"
    }
  },
  "runArgs": [
    "--cap-add=NET_ADMIN",
    "--cap-add=NET_RAW"
  ],
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "eamodio.gitlens"
      ],
      "settings": {
        "editor.formatOnSave": true,
        "editor.defaultFormatter": "esbenp.prettier-vscode",
        "editor.codeActionsOnSave": {
          "source.fixAll.eslint": "explicit"
        },
        "terminal.integrated.defaultProfile.linux": "zsh",
        "terminal.integrated.profiles.linux": {
          "bash": {
            "path": "bash",
            "icon": "terminal-bash"
          },
          "zsh": {
            "path": "zsh"
          }
        }
      }
    }
  },
  "remoteUser": "node",
  "mounts": [
    "source=claude-code-bashhistory-${devcontainerId},target=/commandhistory,type=volume",
    "source=claude-code-config-${devcontainerId},target=/home/node/.claude,type=volume"
  ],
  "containerEnv": {
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude",
    "POWERLEVEL9K_DISABLE_GITSTATUS": "true"
  },
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
  "waitFor": "postStartCommand"
}
```

- [ ] **Step 4: Verify JSON validity and the renamed `name` field**

Run:
```bash
cd ~/spades-dev-environment
node -e "JSON.parse(require('fs').readFileSync('.devcontainer/devcontainer.json','utf8')); console.log('valid JSON')"
grep -q '"name": "SpaDES Dev Environment"' .devcontainer/devcontainer.json && echo "name ok"
grep -q "claude-code-config-\${devcontainerId}" .devcontainer/devcontainer.json && echo "claude config volume mount present"
```
Expected: `valid JSON`, `name ok`, `claude config volume mount present`.

- [ ] **Step 5: Commit**

```bash
cd ~/spades-dev-environment
git add .devcontainer/init-firewall.sh .devcontainer/devcontainer.json
git commit -m "Extend firewall allowlist for Bioconductor/Posit PM/r-universe/Drive, rename devcontainer"
```

---

### Task 7: CI — devcontainer build check

**Files:**
- Create: `.github/workflows/build-devcontainer.yml`

**Interfaces:**
- Consumes: the complete `.devcontainer/` directory from Tasks 4–6
- Produces: a GitHub Actions check that runs on push/PR once this repo exists on GitHub (Task 8) — this is the first point where the Dockerfile actually gets built with a real Docker daemon

- [ ] **Step 1: Write `.github/workflows/build-devcontainer.yml`**

```yaml
name: Build devcontainer

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Build and smoke-test devcontainer
        uses: devcontainers/ci@v0.3
        with:
          imageName: ghcr.io/${{ github.repository }}/devcontainer
          push: never
          runCmd: |
            set -e
            R --version
            Rscript -e 'library(SpaDES.core)'
            claude plugin list
```

- [ ] **Step 2: Verify YAML syntax**

Run:
```bash
cd ~/spades-dev-environment
npx --yes js-yaml .github/workflows/build-devcontainer.yml
```
Expected: prints the parsed structure as JSON (a `name`, `on`, `jobs` object), no parse error.

- [ ] **Step 3: Verify required pieces are present**

Run:
```bash
cd ~/spades-dev-environment
grep -q "devcontainers/ci" .github/workflows/build-devcontainer.yml && echo "uses devcontainers/ci"
grep -q "submodules: recursive" .github/workflows/build-devcontainer.yml && echo "submodule checkout ok"
grep -q "claude plugin list" .github/workflows/build-devcontainer.yml && echo "plugin smoke check present"
```
Expected: all three `... ok`/present lines printed.

- [ ] **Step 4: Commit**

```bash
cd ~/spades-dev-environment
mkdir -p .github/workflows
git add .github/workflows/build-devcontainer.yml
git commit -m "Add CI workflow to build and smoke-test the devcontainer"
```

---

### Task 8: Create and push the GitHub repo

**Requires explicit user confirmation before running** — this creates a public GitHub repository and pushes code to it. `gh auth status` showed no authenticated account in this sandbox as of the design phase; if that's still the case, log in first.

**Files:** none (no local file changes — this task only touches GitHub state)

**Interfaces:**
- Consumes: the fully-committed local repo from Tasks 1–7
- Produces: `https://github.com/AllenLarocque/spades-dev-environment`, public, GPL-3, marked as a template repository, with Actions enabled (Task 7's workflow will run on this push)

- [ ] **Step 1: Confirm GitHub authentication**

Run: `gh auth status`
Expected: shows an authenticated account. If not, run `gh auth login` interactively first (not scriptable — requires user interaction).

- [ ] **Step 2: Create the repo and push**

```bash
cd ~/spades-dev-environment
gh repo create AllenLarocque/spades-dev-environment --public --source=. --remote=origin --push
```
Expected: output includes `https://github.com/AllenLarocque/spades-dev-environment`, and the local `main` branch is now tracking `origin/main`.

- [ ] **Step 3: Mark the repo as a GitHub template repository**

```bash
gh api -X PATCH repos/AllenLarocque/spades-dev-environment -f is_template=true
```

- [ ] **Step 4: Verify**

Run:
```bash
gh repo view AllenLarocque/spades-dev-environment --json isTemplate,visibility,licenseInfo -q '.'
```
Expected: JSON showing `"isTemplate": true`, `"visibility": "PUBLIC"`, and `licenseInfo.spdxId` of `GPL-3.0`.

- [ ] **Step 5: Check the CI run**

Run: `gh run list --repo AllenLarocque/spades-dev-environment --limit 1`
Expected: a run for the `Build devcontainer` workflow, triggered by the push in Step 2. If it fails, the most likely cause (per the risk noted in Task 5) is the `claude plugin install` step hanging or erroring on a non-interactive first run — investigate the run logs (`gh run view --repo AllenLarocque/spades-dev-environment --log-failed`) before deciding on a fix.

---

### Task 9: Revert the uncommitted devcontainer changes in the `claude-code` clone

**Requires explicit user confirmation before running** — this discards uncommitted changes in `/workspace` (the `anthropics/claude-code` clone). Only run this after Task 8's CI run (Step 5) has confirmed the new repo's devcontainer actually builds — don't discard the source material until the copy is verified working.

**Files:**
- Modify: `/workspace/.devcontainer/Dockerfile` (revert to upstream)
- Modify: `/workspace/.devcontainer/init-firewall.sh` (revert to upstream)

**Interfaces:**
- Consumes: confirmation that Task 8 succeeded (the new repo has a working, committed copy of this content)
- Produces: `/workspace` matching `anthropics/claude-code` upstream again, with no stray SpaDES-specific changes

- [ ] **Step 1: Confirm the new repo has everything before discarding anything**

Run:
```bash
diff <(git -C ~/spades-dev-environment show HEAD:.devcontainer/init-firewall.sh 2>/dev/null || true) /dev/null | head -1
git -C ~/spades-dev-environment log --oneline -- .devcontainer/Dockerfile .devcontainer/init-firewall.sh
```
Expected: the log shows the commits from Tasks 4–6 (base Dockerfile, plugin pre-bake, firewall allowlist). If this is empty, stop — do not proceed to Step 2.

- [ ] **Step 2: Revert the claude-code clone's devcontainer changes**

```bash
cd /workspace
git status --short .devcontainer
git checkout -- .devcontainer
git status --short .devcontainer
```
Expected: the first `git status --short` shows `M .devcontainer/Dockerfile` and `M .devcontainer/init-firewall.sh`; the second (after `checkout`) shows no output — the clone now matches `anthropics/claude-code` upstream.

- [ ] **Step 3: Verify the clone is clean**

Run: `git -C /workspace status`
Expected: `nothing to commit, working tree clean` (aside from the pre-existing untracked `docs/` and `projects/` directories, which are unrelated to this plan and out of scope per the design spec's Non-goals).
