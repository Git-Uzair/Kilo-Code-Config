#!/usr/bin/env bash
# Kilo CLI config - macOS/Linux installer
# Idempotent: backs up existing config first.
set -euo pipefail
# Pin history: 7.4.22 -> 7.5.16 (2026-09-09) -> 7.7.1 (2026-09-15) ->
# 7.8.1 (2026-09-26) -> 7.8.18 (2026-11-04). Re-verified on 7.8.18: the
# grep tool returns past its 100-match cap (the Windows hang is gone),
# Claude models get their full output limit (the 32k cap now binds only
# other providers), and a custom agent's edit/bash rules no longer cap
# the subagents it starts. The other 7.4.x-era workarounds (the anthropic
# baseURL pin, the steps-cap and turn-control denies) are NOT re-verified;
# each is harmless on a version that fixed the underlying bug, so all are
# kept.
PIN="7.8.18"
# MCP servers that kilo.jsonc launches by name, pinned beside the CLI
# (see install.ps1)
PKGS=("@kilocode/cli@${PIN}" "firecrawl-mcp@3.36.1" "@playwright/mcp@0.0.84")
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ "${1:-}" = "--latest" ]; then
  PKGS=("@kilocode/cli@latest" "firecrawl-mcp@latest" "@playwright/mcp@latest")
fi

echo "== Kilo CLI config installer =="
for tool in node npm; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool required but not on PATH"; exit 1; }
done
# firecrawl-mcp declares engines node >=22.0.0
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "ERROR: Node.js 22 or newer is required (found $(node --version)): the Firecrawl MCP server needs it"
  exit 1
fi

# Back up before the CLI install: the first kilo invocation (the version
# check below) auto-creates a skeleton ~/.config/kilo, which would otherwise
# get backed up as if it were prior user state.
CFG="$HOME/.config/kilo"
KILO="$HOME/.kilo"
for d in "$CFG" "$KILO"; do
  if [ -d "$d" ]; then
    echo "Backing up $d -> $d.bak-$STAMP"
    cp -r "$d" "$d.bak-$STAMP"
  fi
done

# the Kilo CLI and the MCP servers kilo.jsonc launches by name
echo "Installing ${PKGS[*]} ..."
npm install -g "${PKGS[@]}"
echo "kilo version: $(kilo --version)"
# the Playwright MCP drives Google Chrome (--browser chrome); these are the
# paths Playwright itself checks. Installing Chrome is left to the user.
case "$(uname -s)" in
  Darwin) CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ;;
  *) CHROME="/opt/google/chrome/chrome" ;;
esac
if [ -x "$CHROME" ]; then
  echo "Google Chrome found for the Playwright MCP: $CHROME"
else
  echo "WARN: Google Chrome not found at $CHROME. The browser tools (Playwright MCP) need it:"
  echo "  install it from https://www.google.com/chrome/ or run: npx playwright install chrome (needs admin rights)"
fi
mkdir -p "$CFG/agents" "$KILO/skills"
cp "$REPO_ROOT/config/kilo.jsonc" "$CFG/"
cp "$REPO_ROOT/config/instructions.md" "$CFG/"
# agents: ~/.config/kilo/agents mirrors config/agents (see install.ps1 step 4)
for f in "$CFG"/agents/*.md; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  if [ ! -f "$REPO_ROOT/config/agents/$name" ]; then
    rm -f "$f"
    echo "  removed agent ${name%.md} (not shipped by this repo)"
  fi
done
cp "$REPO_ROOT"/config/agents/*.md "$CFG/agents/"
echo "Config installed to $CFG"

# skills: ~/.kilo/skills mirrors skills/ in this repo (see install.ps1 step 5)
POOL="$KILO/skills"
for d in "$POOL"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  if [ ! -f "$REPO_ROOT/skills/$name/SKILL.md" ]; then
    rm -rf "${d%/}"
    echo "  removed $name (not shipped by this repo)"
  fi
done
for s in "$REPO_ROOT"/skills/*/; do
  [ -f "$s/SKILL.md" ] || continue
  name="$(basename "$s")"
  rm -rf "$POOL/$name"
  mkdir -p "$POOL/$name"
  cp -r "$s". "$POOL/$name/"
  echo "  -> $name"
done
# leftovers of the clone-based installer (before 2026-10-05)
rm -rf "$KILO/update-skills.ps1" "$KILO/local-skills" "$KILO/skill-repos"

# kopipasta - the context oracle behind the codebase-map skill (best effort)
if command -v uv >/dev/null 2>&1; then
  uv tool install --force kopipasta || echo "WARN: kopipasta install failed"
elif command -v pip3 >/dev/null 2>&1; then
  pip3 install --upgrade kopipasta || echo "WARN: kopipasta install failed"
else
  echo "WARN: neither uv nor pip3 found - skipping kopipasta. The codebase-map skill needs it: uv tool install kopipasta"
fi

# herdr TUI (optional) - wired only when already on PATH, never downloaded
# here (see install.ps1 step 7)
if command -v herdr >/dev/null 2>&1; then
  HERDR_CFG="$HOME/.config/herdr/config.toml"
  mkdir -p "$(dirname "$HERDR_CFG")"
  if [ -f "$HERDR_CFG" ]; then
    echo "Backing up $HERDR_CFG -> $HERDR_CFG.bak-$STAMP"
    cp "$HERDR_CFG" "$HERDR_CFG.bak-$STAMP"
  fi
  cp "$REPO_ROOT/config/herdr/config.toml" "$HERDR_CFG"
  # the config's Kilo keys load kilo.cjs from beside it
  cp "$REPO_ROOT/config/herdr/kilo.cjs" "$(dirname "$HERDR_CFG")/kilo.cjs"
  echo "Herdr config installed to $HERDR_CFG"
  echo "  (herdr already running? apply it with: herdr server reload-config)"
  herdr integration install kilo || echo "WARN: herdr integration install kilo failed - retry it by hand"
  herdr integration status || true
else
  echo "Herdr not found - skipped (optional). To add it, install it, then re-run this installer:"
  echo "  curl -fsSL https://herdr.dev/install.sh | sh"
fi

echo ""
echo "== Set your API keys (add to your shell profile) =="
echo '  export GOOGLE_GENERATIVE_AI_API_KEY="<your-google-key>"'
echo '  export ANTHROPIC_API_KEY="<anthropic-key-for-boss>"'
echo '  export FIRECRAWL_API_KEY="<optional-firecrawl-key>"'
echo '  export GEMINI_API_KEY="<optional-key-for-kopipasta-ask>"'
echo "  (ANTHROPIC_API_KEY is needed for @boss only; the Google key runs everything else)"
echo "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
echo "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
echo ""
echo "  Already have a kilo TUI open? Restart it - a running process keeps the"
echo "  environment it started with and will not see keys you set just now."

echo ""
echo "== Agent roster =="
# no 2>&1: first-run migration progress arrives on stderr and should stream
# to the console; roster lines are on stdout
kilo agent list | grep -E '^\S+ \((primary|subagent|all)\)' || true
echo ""
echo "== MCP servers =="
# status lines only; the command lines below them contain "-mcp"
kilo mcp list | grep -E 'firecrawl|playwright' | grep -v -- '-mcp' || true
echo ""
echo "Done. Expected custom agents: quick (default), boss, argon, carbon, gemini-coder."
echo "      Expected MCP servers: firecrawl and playwright, both connected."
echo "Try:  kilo   (opens the TUI in quick; Tab cycles to boss, argon, and carbon)"
