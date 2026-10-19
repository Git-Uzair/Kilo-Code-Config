# Kilo multi-agent pipeline - Windows installer
# PowerShell 5.1 compatible. Idempotent: backs up existing config first.
param(
    [switch]$Latest  # install newest @kilocode/cli instead of the tested pin
)
$ErrorActionPreference = 'Stop'
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
$pin = '7.8.1'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "== Kilo multi-agent pipeline installer ==" -ForegroundColor Cyan

# 1. Prerequisites
foreach ($tool in @('node', 'npm')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required but not on PATH. Install it and re-run."
    }
}

# 2. Back up any existing state - before the CLI install: the first kilo
# invocation (the version check below) auto-creates a skeleton ~/.config/kilo,
# which would otherwise get backed up as if it were prior user state.
$cfgDir = Join-Path $HOME '.config\kilo'
$kiloDir = Join-Path $HOME '.kilo'
foreach ($d in @($cfgDir, $kiloDir)) {
    if (Test-Path $d) {
        $bak = "$d.bak-$stamp"
        Write-Host "Backing up $d -> $bak"
        Copy-Item $d $bak -Recurse -Force
    }
}

# 3. Kilo CLI
if ($Latest) { $pkg = '@kilocode/cli@latest' } else { $pkg = "@kilocode/cli@$pin" }
Write-Host "Installing $pkg ..."
npm install -g $pkg
if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
Write-Host ("kilo version: " + (kilo --version))

# 4. Copy config
New-Item -ItemType Directory -Force (Join-Path $cfgDir 'agents') | Out-Null
Copy-Item (Join-Path $repoRoot 'config\kilo.jsonc') $cfgDir -Force
Copy-Item (Join-Path $repoRoot 'config\instructions.md') $cfgDir -Force
Copy-Item (Join-Path $repoRoot 'config\agents\*.md') (Join-Path $cfgDir 'agents') -Force
Write-Host "Config installed to $cfgDir"

# 5. Skills: ~/.kilo/skills mirrors skills/ in this repo. Every shipped
# skill is copied fresh; anything else in the pool is removed (the backup
# above keeps it). To keep a skill of your own, add it to skills/ here.
$pool = Join-Path $kiloDir 'skills'
New-Item -ItemType Directory -Force $pool | Out-Null
$shipped = @(Get-ChildItem (Join-Path $repoRoot 'skills') -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') })
foreach ($dir in Get-ChildItem $pool -Directory) {
    if ($shipped.Name -notcontains $dir.Name) {
        Remove-Item $dir.FullName -Recurse -Force
        Write-Host "  removed $($dir.Name) (not shipped by this repo)"
    }
}
foreach ($skill in $shipped) {
    $dest = Join-Path $pool $skill.Name
    # Remove first: Copy-Item onto an existing folder nests the source
    # inside it (skills/<name>/<name>/SKILL.md), and stale files survive.
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $skill.FullName $dest -Recurse
    Write-Host "  -> $($skill.Name)"
}
# Leftovers of the clone-based installer (before 2026-10-05): the old
# update-skills.ps1 would re-install the retired skill sets if run.
foreach ($old in @('update-skills.ps1', 'local-skills', 'skill-repos')) {
    $p = Join-Path $kiloDir $old
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force
        Write-Host "  removed ~/.kilo/$old"
    }
}

# 6. kopipasta - the context oracle behind the codebase-map skill.
# Best-effort: no Python toolchain must never fail a Kilo install.
$kopiOk = $false
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "Installing kopipasta (uv) ..."
    uv tool install --force kopipasta
    $kopiOk = ($LASTEXITCODE -eq 0)
}
elseif (Get-Command pip -ErrorAction SilentlyContinue) {
    Write-Host "Installing kopipasta (pip) ..."
    pip install --upgrade kopipasta
    $kopiOk = ($LASTEXITCODE -eq 0)
}
if ($kopiOk) {
    # 0.70.0 introduced the verbs; older builds have no `map`.
    Write-Host "kopipasta installed. Verify with: kopipasta map --help"
    Write-Host "  (standard invocation used across agents: kopipasta map --json)"
}
else {
    Write-Warning "kopipasta not installed (needs uv or pip). The codebase-map skill falls back to plain reads until you run: uv tool install kopipasta"
}

# 7. API keys - never stored, never echoed
Write-Host ""
Write-Host "== Set your API keys (user scope, new terminals pick them up) ==" -ForegroundColor Yellow
Write-Host '  [Environment]::SetEnvironmentVariable("GOOGLE_GENERATIVE_AI_API_KEY","<your-google-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("AWS_BEARER_TOKEN_BEDROCK","<your-bedrock-api-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","<anthropic-key-for-boss>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("OPENAI_API_KEY","<openai-key-for-astra>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("GEMINI_API_KEY","<optional-key-for-kopipasta-ask>","User")'
Write-Host "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
Write-Host "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
Write-Host ""
Write-Host "  Bedrock notes:" -ForegroundColor Yellow
Write-Host "    - Use a LONG-TERM Bedrock API key; short-term ones expire in <=12h."
Write-Host "    - Use SetEnvironmentVariable above, not setx: setx truncates at 1024"
Write-Host "      chars and a silently-truncated key fails auth with no clear cause."
Write-Host "    - Claude Opus 5 model access must be granted in the Bedrock console."
Write-Host "    - No AWS_REGION needed: the region is pinned in kilo.jsonc."
Write-Host "    - ANTHROPIC_API_KEY: needed for @boss (Opus 5.5); otherwise optional -"
Write-Host "      it is also the Opus rollback path."
Write-Host ""
Write-Host "  Already have a kilo TUI open? Restart it." -ForegroundColor Yellow
Write-Host "  A running process keeps the environment it started with and will not"
Write-Host "  see keys you set just now."

# 8. Verify
Write-Host ""
Write-Host "== Agent roster ==" -ForegroundColor Cyan
# No 2>&1 here: kilo reports first-run DB migration progress on stderr, and in
# PowerShell 5.1 redirecting native stderr under ErrorActionPreference=Stop
# raises a terminating NativeCommandError. Roster lines arrive on stdout;
# stderr streams to the console as live progress.
kilo agent list | Select-String -Pattern '^\S+ \((primary|subagent|all)\)' | ForEach-Object { $_.Line }
Write-Host ""
Write-Host "Done. Expected custom agents: conductor, quick, worker, planner, coder, opus-coder, verifier, verifier-lite, boss, astra, argon."
Write-Host "Try:  kilo run --dir <repo> --auto `"your task`""
