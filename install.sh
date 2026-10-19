#!/usr/bin/env bash
# Kilo multi-agent pipeline - macOS/Linux installer
# Idempotent: backs up existing config first.
set -euo pipefail
# Pin history: 7.4.22 -> 7.5.16 (2026-09-09) -> 7.7.1 (2026-09-15) -> 7.8.1 (2026-09-26). The
# 7.7.1 bump is required by the config itself: the worker agent's
# resume-based PIPELINE, the Kilo Swarm shared board (on by default since
# 7.7.0), codebase indexing / semantic_search, and wakeup scheduling all
# need >=7.6/7.7. The 7.4.x-era findings this config encodes (README design
# notes, the anthropic baseURL pin, the grep/Bun hang, steps-cap and
# turn-control workarounds) have NOT been re-verified on 7.7.1 - each is
# harmless on a version that fixed the underlying bug, so all are kept.
# (interactive_terminal was removed upstream in 7.6.0; its deny lines are
# inert on 7.7.1 and retained only for older installs.)
PIN="7.8.1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PKG="@kilocode/cli@${PIN}"
[ "${1:-}" = "--latest" ] && PKG="@kilocode/cli@latest"

echo "== Kilo multi-agent pipeline installer =="
for tool in node npm; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool required but not on PATH"; exit 1; }
done

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

echo "Installing $PKG ..."
npm install -g "$PKG"
echo "kilo version: $(kilo --version)"
mkdir -p "$CFG/agents" "$KILO/skills"
cp "$REPO_ROOT/config/kilo.jsonc" "$CFG/"
cp "$REPO_ROOT/config/instructions.md" "$CFG/"
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

echo ""
echo "== Set your API keys (add to your shell profile) =="
echo '  export GOOGLE_GENERATIVE_AI_API_KEY="<your-google-key>"'
echo '  export AWS_BEARER_TOKEN_BEDROCK="<your-bedrock-api-key>"'
echo '  export ANTHROPIC_API_KEY="<anthropic-key-for-boss>"'
echo '  export OPENAI_API_KEY="<openai-key-for-astra>"'
echo '  export FIRECRAWL_API_KEY="<optional-firecrawl-key>"'
echo '  export GEMINI_API_KEY="<optional-key-for-kopipasta-ask>"'
echo "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
echo "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
echo ""
echo "  Bedrock notes:"
echo "    - Use a LONG-TERM Bedrock API key; short-term ones expire in <=12h."
echo "    - Claude Opus 5 model access must be granted in the Bedrock console."
echo "    - No AWS_REGION needed: the region is pinned in kilo.jsonc."
echo "    - ANTHROPIC_API_KEY: needed for @boss (Opus 5.5); otherwise optional -"
echo "      it is also the Opus rollback path."
echo ""
echo "  Already have a kilo TUI open? Restart it - a running process keeps the"
echo "  environment it started with and will not see keys you set just now."

echo ""
echo "== Agent roster =="
# no 2>&1: first-run migration progress arrives on stderr and should stream
# to the console; roster lines are on stdout
kilo agent list | grep -E '^\S+ \((primary|subagent|all)\)' || true
echo ""
echo "Done. Expected custom agents: conductor, quick, worker, planner, coder, opus-coder, verifier, verifier-lite, boss, astra, argon."
echo 'Try:  kilo run --dir <repo> --auto "your task"'
