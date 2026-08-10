# Kilo multi-agent pipeline - Windows installer
# PowerShell 5.1 compatible. Idempotent: backs up existing config first.
param(
    [switch]$Latest  # install newest @kilocode/cli instead of the tested pin
)
$ErrorActionPreference = 'Stop'
$pin = '7.4.20'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "== Kilo multi-agent pipeline installer ==" -ForegroundColor Cyan

# 1. Prerequisites
foreach ($tool in @('git', 'node', 'npm')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required but not on PATH. Install it and re-run."
    }
}

# 2. Kilo CLI
if ($Latest) { $pkg = '@kilocode/cli@latest' } else { $pkg = "@kilocode/cli@$pin" }
Write-Host "Installing $pkg ..."
npm install -g $pkg
if ($LASTEXITCODE -ne 0) { throw "npm install failed (exit $LASTEXITCODE)" }
Write-Host ("kilo version: " + (kilo --version))

# 3. Back up any existing state, then copy config
$cfgDir = Join-Path $HOME '.config\kilo'
$kiloDir = Join-Path $HOME '.kilo'
foreach ($d in @($cfgDir, $kiloDir)) {
    if (Test-Path $d) {
        $bak = "$d.bak-$stamp"
        Write-Host "Backing up $d -> $bak"
        Copy-Item $d $bak -Recurse -Force
    }
}
New-Item -ItemType Directory -Force (Join-Path $cfgDir 'agents') | Out-Null
Copy-Item (Join-Path $repoRoot 'config\kilo.jsonc') $cfgDir -Force
Copy-Item (Join-Path $repoRoot 'config\instructions.md') $cfgDir -Force
Copy-Item (Join-Path $repoRoot 'config\agents\*.md') (Join-Path $cfgDir 'agents') -Force
Write-Host "Config installed to $cfgDir"

# 4. Skill repositories + curated skill set
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
    } else {
        Write-Host "Cloning $name ..."
        git clone --depth 1 $sources[$name] $dest
    }
    if ($LASTEXITCODE -ne 0) { throw "git failed for $name (exit $LASTEXITCODE)" }
}
Copy-Item (Join-Path $repoRoot 'scripts\update-skills.ps1') $kiloDir -Force
& (Join-Path $kiloDir 'update-skills.ps1')

# 5. API keys - never stored, never echoed
Write-Host ""
Write-Host "== Set your API keys (user scope, new terminals pick them up) ==" -ForegroundColor Yellow
Write-Host '  [Environment]::SetEnvironmentVariable("GOOGLE_GENERATIVE_AI_API_KEY","<your-google-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","<your-anthropic-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")'
Write-Host "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"

# 6. Verify
Write-Host ""
Write-Host "== Agent roster ==" -ForegroundColor Cyan
kilo agent list 2>&1 | Select-String -Pattern '^\S+ \((primary|subagent|all)\)' | ForEach-Object { $_.Line }
Write-Host ""
Write-Host "Done. Expected custom agents: conductor, planner, coder, opus-coder, verifier."
Write-Host "Try:  kilo run --dir <repo> --auto `"your task`""
