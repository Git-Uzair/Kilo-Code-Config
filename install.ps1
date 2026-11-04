# Kilo CLI config - Windows installer
# PowerShell 5.1 compatible. Idempotent: backs up existing config first.
param(
    [switch]$Latest  # install newest @kilocode/cli instead of the tested pin
)
$ErrorActionPreference = 'Stop'
# Pin history: 7.4.22 -> 7.5.16 (2026-09-09) -> 7.7.1 (2026-09-15) ->
# 7.8.1 (2026-09-26) -> 7.8.18 (2026-11-04). Re-verified on 7.8.18: the
# grep tool returns past its 100-match cap (the Windows hang is gone),
# Claude models get their full output limit (the 32k cap now binds only
# other providers), and a custom agent's edit/bash rules no longer cap
# the subagents it starts. The other 7.4.x-era workarounds (the anthropic
# baseURL pin, the steps-cap and turn-control denies) are NOT re-verified;
# each is harmless on a version that fixed the underlying bug, so all are
# kept.
$pin = '7.8.18'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-Host "== Kilo CLI config installer ==" -ForegroundColor Cyan

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

# 4. Copy config. ~/.config/kilo/agents mirrors config/agents: an agent
# this repo no longer ships is removed (the backup above keeps it), so a
# retired agent cannot linger in the picker. To keep an agent of your
# own, add it to config/agents here.
$agentsDir = Join-Path $cfgDir 'agents'
New-Item -ItemType Directory -Force $agentsDir | Out-Null
Copy-Item (Join-Path $repoRoot 'config\kilo.jsonc') $cfgDir -Force
Copy-Item (Join-Path $repoRoot 'config\instructions.md') $cfgDir -Force
$agents = @(Get-ChildItem (Join-Path $repoRoot 'config\agents') -Filter *.md)
foreach ($f in Get-ChildItem $agentsDir -Filter *.md) {
    if ($agents.Name -notcontains $f.Name) {
        Remove-Item $f.FullName -Force
        Write-Host "  removed agent $($f.BaseName) (not shipped by this repo)"
    }
}
Copy-Item (Join-Path $repoRoot 'config\agents\*.md') $agentsDir -Force
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
Write-Host '  [Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","<anthropic-key-for-boss>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")'
Write-Host '  [Environment]::SetEnvironmentVariable("GEMINI_API_KEY","<optional-key-for-kopipasta-ask>","User")'
Write-Host "  (ANTHROPIC_API_KEY is needed for @boss only; the Google key runs everything else)"
Write-Host "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
Write-Host "  (no Firecrawl key? remove the mcp.firecrawl block from ~/.config/kilo/kilo.jsonc)"
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
Write-Host "Done. Expected custom agents: quick (default), boss, argon, coder."
Write-Host "Try:  kilo   (opens the TUI in quick; Tab cycles to boss and argon)"
