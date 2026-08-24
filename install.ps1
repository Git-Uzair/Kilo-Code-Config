# Kilo multi-agent pipeline - Windows installer
# PowerShell 5.1 compatible. Idempotent: backs up existing config first.
param(
    [switch]$Latest  # install newest @kilocode/cli instead of the tested pin
)
$ErrorActionPreference = 'Stop'
$pin = '7.4.22'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "== Kilo multi-agent pipeline installer ==" -ForegroundColor Cyan

# 1. Prerequisites
foreach ($tool in @('git', 'node', 'npm')) {
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

# 5. Skill repositories + curated skill set
$repos = Join-Path $kiloDir 'skill-repos'
New-Item -ItemType Directory -Force $repos, (Join-Path $kiloDir 'skills') | Out-Null
$sources = @{
    'superpowers'      = 'https://github.com/obra/superpowers'
    'ponytail'         = 'https://github.com/DietrichGebert/ponytail'
    'anthropic-skills' = 'https://github.com/anthropics/skills'
}
foreach ($name in $sources.Keys) {
    $dest = Join-Path $repos $name
    if (Test-Path (Join-Path $dest '.git')) {
        Write-Host "Repo exists, pulling: $name"
        git -C $dest pull --ff-only
    }
    else {
        Write-Host "Cloning $name ..."
        git clone --depth 1 $sources[$name] $dest
    }
    if ($LASTEXITCODE -ne 0) { throw "git failed for $name (exit $LASTEXITCODE)" }
}

# Local skills shipped in this repo (skills/<name>/SKILL.md). Mirrored to
# ~/.kilo/local-skills so the standalone update-skills.ps1 can refresh them
# later without knowing where this repo was cloned.
$localSrc = Join-Path $repoRoot 'skills'
$localMirror = Join-Path $kiloDir 'local-skills'
if (Test-Path $localSrc) {
    foreach ($skill in Get-ChildItem $localSrc -Directory) {
        foreach ($dest in @((Join-Path $localMirror $skill.Name), (Join-Path (Join-Path $kiloDir 'skills') $skill.Name))) {
            New-Item -ItemType Directory -Force $dest | Out-Null
            Copy-Item (Join-Path $skill.FullName '*') $dest -Recurse -Force
        }
        Write-Host "  -> $($skill.Name) (local)"
    }
}

Copy-Item (Join-Path $repoRoot 'scripts\update-skills.ps1') $kiloDir -Force
& (Join-Path $kiloDir 'update-skills.ps1')

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
Write-Host "    - ANTHROPIC_API_KEY: needed for @boss (Fable 5, org must have model"
Write-Host "      access); otherwise optional - it is also the Opus rollback path."
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
Write-Host "Done. Expected custom agents: conductor, quick, planner, coder, opus-coder, verifier, verifier-lite, boss."
Write-Host "Try:  kilo run --dir <repo> --auto `"your task`""
