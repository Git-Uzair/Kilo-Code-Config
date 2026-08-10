#!/usr/bin/env bash
# Kilo multi-agent pipeline - macOS/Linux installer
# Idempotent: backs up existing config first.
set -euo pipefail
PIN="7.4.20"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PKG="@kilocode/cli@${PIN}"
[ "${1:-}" = "--latest" ] && PKG="@kilocode/cli@latest"

echo "== Kilo multi-agent pipeline installer =="
for tool in git node npm; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool required but not on PATH"; exit 1; }
done

echo "Installing $PKG ..."
npm install -g "$PKG"
echo "kilo version: $(kilo --version)"

CFG="$HOME/.config/kilo"
KILO="$HOME/.kilo"
for d in "$CFG" "$KILO"; do
  if [ -d "$d" ]; then
    echo "Backing up $d -> $d.bak-$STAMP"
    cp -r "$d" "$d.bak-$STAMP"
  fi
done
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

echo ""
echo "== Set your API keys (add to your shell profile) =="
echo '  export GOOGLE_GENERATIVE_AI_API_KEY="<your-google-key>"'
echo '  export ANTHROPIC_API_KEY="<your-anthropic-key>"'
echo '  export FIRECRAWL_API_KEY="<optional-firecrawl-key>"'
echo "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"

echo ""
echo "== Agent roster =="
kilo agent list 2>&1 | grep -E '^\S+ \((primary|subagent|all)\)' || true
echo ""
echo "Done. Expected custom agents: conductor, planner, coder, opus-coder, verifier."
echo 'Try:  kilo run --dir <repo> --auto "your task"'
