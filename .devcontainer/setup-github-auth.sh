#!/usr/bin/env bash
# Make GitHub auth survive /tmp cleanup, VS Code reconnects, and container rebuilds.
#
# THREE INDEPENDENT FAILURE MODES were diagnosed 2026-07-29, each losing auth on its own:
#
#   1. `git push` — git's credential.helper is a VS Code script at
#      /tmp/vscode-remote-containers-<uuid>.js, configured in BOTH /etc/gitconfig and
#      ~/.gitconfig. When /tmp is cleaned, or VS Code reconnects with a new uuid, that path
#      goes stale and git has NO other helper to fall back to -- so it prompts, and the push
#      dies with the misleading "Invalid username or token".
#   2. `gh` CLI — a device-flow token in hosts.yml went invalid after ~24 h, twice. Both times
#      `gh auth login` reported "already logged in" and then worked, i.e. it refreshed an
#      EXPIRED token rather than creating a missing one. Persistence cannot fix an expiry; only
#      a PAT avoids it.
#   3. rebuild — ~/.config/gh lives in $HOME, which a rebuild wipes (the same axis that takes
#      the R library).
#
# This script is idempotent and must NEVER fail the container start: every step is guarded, and
# it always exits 0.

set -uo pipefail

log() { printf '[github-auth] %s\n' "$*"; }

# ── 1. Persist gh's config in a volume that already survives rebuilds ───────────────────────
# GH_CONFIG_DIR (set in devcontainer.json) points gh at /home/node/.claude/gh, inside the
# existing claude-code-config volume. Deliberately NOT a new named volume: a fresh named volume
# mounts root-owned, and gh runs as `node`, so it could not write there. Reusing the .claude
# volume gives persistence AND correct ownership for free.
GH_DIR="${GH_CONFIG_DIR:-/home/node/.claude/gh}"
mkdir -p "$GH_DIR" 2>/dev/null || true
chmod 700 "$GH_DIR" 2>/dev/null || true

# One-time migration: carry an existing token over from the pre-GH_CONFIG_DIR location so the
# first rebuild after this change does not force a re-auth.
if [ ! -f "$GH_DIR/hosts.yml" ] && [ -f "$HOME/.config/gh/hosts.yml" ]; then
  cp "$HOME/.config/gh/hosts.yml" "$GH_DIR/hosts.yml" 2>/dev/null \
    && chmod 600 "$GH_DIR/hosts.yml" 2>/dev/null \
    && log "migrated existing token from ~/.config/gh"
fi

# ── 2. Prefer a PAT when the host supplies one ───────────────────────────────────────────────
# Set GH_PAT on the HOST (e.g. `export GH_PAT=github_pat_...` in your shell profile) and
# devcontainer.json forwards it as GH_PAT_FROM_HOST. Unset on the host is fine -- the variable
# arrives empty and this block is skipped.
#
# ⚠️ Deliberately NOT named GH_TOKEN/GITHUB_TOKEN: gh reads those directly, and an EMPTY value
# would override the valid token in hosts.yml and break auth entirely.
#
# ⚠️ Also deliberately NOT a bind mount of a host secret file: if the host path does not exist,
# Docker creates a DIRECTORY there and the container start becomes the new failure mode.
#
# Scope the PAT to this repo only -- Contents: read/write, Pull requests: read/write. That is
# what `git push` plus the `gh api ... /pulls/<n>` body updates need, and nothing more.
if [ -n "${GH_PAT_FROM_HOST:-}" ]; then
  if printf '%s' "$GH_PAT_FROM_HOST" | gh auth login --with-token 2>/dev/null; then
    log "authenticated gh from the host-supplied PAT"
  else
    log "WARNING: host PAT was present but gh rejected it -- check its scopes/expiry"
  fi
fi

# ── 3. Give git a working fallback credential helper ─────────────────────────────────────────
# This does NOT remove VS Code's helper, deliberately. git consults helpers in configuration
# order until one returns credentials, so the fix is to ensure a WORKING one exists AFTER
# theirs -- not to fight a helper that VS Code rewrites on every attach.
if gh auth status >/dev/null 2>&1; then
  gh auth setup-git 2>/dev/null && log "gh registered as a git credential helper (fallback)"
else
  log "NOTE: gh is not authenticated. Run 'gh auth login' once, or set GH_PAT on the host."
fi

exit 0
