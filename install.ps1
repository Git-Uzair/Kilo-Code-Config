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
Copy-Item (Join-Path $repoRoot 'scripts\update-skills.ps1') $kiloDir -Force
& (Join-Path $kiloDir 'update-skills.ps1')

# 6. API keys - never stored, never echoed
Write-Host ""
Write-Host "== Set your API keys (user scope, new terminals pick them up) ==" -ForegroundColor Yellow
Write-Host '  [Environment]::SetEnvironmentVariable("GOOGLE_GENERATIVE_AI_API_KEY","<your-google-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("AWS_BEARER_TOKEN_BEDROCK","<your-bedrock-api-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","<optional-anthropic-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")'
Write-Host "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
Write-Host ""
Write-Host "  Bedrock notes:" -ForegroundColor Yellow
Write-Host "    - Use a LONG-TERM Bedrock API key; short-term ones expire in <=12h."
Write-Host "    - Use SetEnvironmentVariable above, not setx: setx truncates at 1024"
Write-Host "      chars and a silently-truncated key fails auth with no clear cause."
Write-Host "    - Claude Opus 5 model access must be granted in the Bedrock console."
Write-Host "    - No AWS_REGION needed: the region is pinned in kilo.jsonc."
Write-Host "    - ANTHROPIC_API_KEY is optional - rollback path only."
Write-Host ""
Write-Host "  Already have a kilo TUI open? Restart it." -ForegroundColor Yellow
Write-Host "  A running process keeps the environment it started with and will not"
Write-Host "  see keys you set just now."

# 7. Verify
Write-Host ""
Write-Host "== Agent roster ==" -ForegroundColor Cyan
# No 2>&1 here: kilo reports first-run DB migration progress on stderr, and in
# PowerShell 5.1 redirecting native stderr under ErrorActionPreference=Stop
# raises a terminating NativeCommandError. Roster lines arrive on stdout;
# stderr streams to the console as live progress.
kilo agent list | Select-String -Pattern '^\S+ \((primary|subagent|all)\)' | ForEach-Object { $_.Line }
Write-Host ""
Write-Host "Done. Expected custom agents: conductor, planner, coder, opus-coder, verifier."
Write-Host "Try:  kilo run --dir <repo> --auto `"your task`""
