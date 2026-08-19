#!/usr/bin/env bash
# Kilo multi-agent pipeline - macOS/Linux installer
# Idempotent: backs up existing config first.
set -euo pipefail
PIN="7.4.22"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PKG="@kilocode/cli@${PIN}"
[ "${1:-}" = "--latest" ] && PKG="@kilocode/cli@latest"

echo "== Kilo multi-agent pipeline installer =="
for tool in git node npm; do
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
mkdir -p "$CFG/agents" "$KILO/skill-repos" "$KILO/skills"
cp "$REPO_ROOT/config/kilo.jsonc" "$CFG/"
cp "$REPO_ROOT/config/instructions.md" "$CFG/"
cp "$REPO_ROOT"/config/agents/*.md "$CFG/agents/"
echo "Config installed to $CFG"

clone_or_pull() {
  local name="$1" url="$2" dest="$KILO/skill-repos/$1"
  if [ -d "$dest/.git" ]; then git -C "$dest" pull --ff-only
  else git clone --depth 1 "$url" "$dest"; fi
}
clone_or_pull superpowers      https://github.com/obra/superpowers
clone_or_pull ponytail         https://github.com/DietrichGebert/ponytail
clone_or_pull anthropic-skills https://github.com/anthropics/skills

# curated skill set (mirror of scripts/update-skills.ps1)
copy_skills() {
  local repo="$1"; shift
  for s in "$@"; do
    src="$KILO/skill-repos/$repo/skills/$s"
    [ -f "$src/SKILL.md" ] || { echo "WARN: missing upstream skill $repo/$s"; continue; }
    rm -rf "$KILO/skills/$s"
    cp -r "$src" "$KILO/skills/$s"
    echo "  -> $s"
  done
}
copy_skills superpowers test-driven-development systematic-debugging \
  verification-before-completion writing-plans executing-plans \
  subagent-driven-development dispatching-parallel-agents \
  requesting-code-review receiving-code-review
copy_skills ponytail ponytail ponytail-review
copy_skills anthropic-skills frontend-design skill-creator webapp-testing

# local skills shipped in this repo; mirrored so update-skills.ps1 can
# refresh them later without knowing where this repo was cloned
if [ -d "$REPO_ROOT/skills" ]; then
  for s in "$REPO_ROOT"/skills/*/; do
    [ -f "$s/SKILL.md" ] || continue
    name="$(basename "$s")"
    mkdir -p "$KILO/skills/$name" "$KILO/local-skills/$name"
    cp -r "$s". "$KILO/skills/$name/"
    cp -r "$s". "$KILO/local-skills/$name/"
    echo "  -> $name (local)"
  done
fi

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
echo '  export ANTHROPIC_API_KEY="<optional-anthropic-key>"'
echo '  export FIRECRAWL_API_KEY="<optional-firecrawl-key>"'
echo '  export GEMINI_API_KEY="<optional-key-for-kopipasta-ask>"'
echo "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
echo "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
echo ""
echo "  Bedrock notes:"
echo "    - Use a LONG-TERM Bedrock API key; short-term ones expire in <=12h."
echo "    - Claude Opus 5 model access must be granted in the Bedrock console."
echo "    - No AWS_REGION needed: the region is pinned in kilo.jsonc."
echo "    - ANTHROPIC_API_KEY is optional - rollback path only."
echo ""
echo "  Already have a kilo TUI open? Restart it - a running process keeps the"
echo "  environment it started with and will not see keys you set just now."

echo ""
echo "== Agent roster =="
# no 2>&1: first-run migration progress arrives on stderr and should stream
# to the console; roster lines are on stdout
kilo agent list | grep -E '^\S+ \((primary|subagent|all)\)' || true
echo ""
echo "Done. Expected custom agents: conductor, planner, coder, opus-coder, verifier."
echo 'Try:  kilo run --dir <repo> --auto "your task"'
