# Re-vendors the third-party skills pinned in skills/vendor.psd1 into
# skills/<name>/, each with its upstream license file(s), then checks that
# every skill a shipped skill references is shipped too.
# Maintainer tool: run it, review `git diff -- skills`, commit. The
# installers never run it - they copy skills/ exactly as committed.
#   .\scripts\sync-skills.ps1             re-vendor at the pinned commits
#   .\scripts\sync-skills.ps1 -Latest     vendor each default-branch tip and
#                                         print the commits to re-pin
#   .\scripts\sync-skills.ps1 -CheckOnly  closure check only; skills/ untouched
param([switch]$Latest, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$skillsDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'skills'
$manifest = Import-PowerShellDataFile (Join-Path $skillsDir 'vendor.psd1')
$work = Join-Path $env:TEMP 'kilo\skill-sync'
New-Item -ItemType Directory -Force $work | Out-Null

$catalog = @()
foreach ($src in $manifest.Sources) {
    $clone = Join-Path $work (($src.Repo -split '/')[-2..-1] -join '-')
    if (Test-Path (Join-Path $clone '.git')) {
        git -C $clone fetch --quiet origin
    }
    else {
        # autocrlf off: vendored bytes match upstream exactly
        git clone --quiet --filter=blob:none -c core.autocrlf=false $src.Repo $clone
    }
    if ($LASTEXITCODE -ne 0) { throw "git fetch/clone failed: $($src.Repo)" }
    $ref = if ($Latest) { 'origin/HEAD' } else { $src.Commit }
    git -C $clone checkout --quiet --detach $ref
    if ($LASTEXITCODE -ne 0) { throw "cannot check out $ref in $($src.Repo)" }
    $sha = git -C $clone rev-parse HEAD
    if ($sha -ne $src.Commit) { Write-Host "RE-PIN $($src.Repo): Commit = '$sha'" -ForegroundColor Yellow }
    $catalog += Get-ChildItem $clone -Recurse -File -Filter SKILL.md | ForEach-Object { $_.Directory.Name }
    if ($CheckOnly) { continue }
    foreach ($name in $src.Skills.Keys) {
        $from = Join-Path $clone $src.Skills[$name]
        if (-not (Test-Path (Join-Path $from 'SKILL.md'))) { throw "gone upstream: $($src.Repo) $($src.Skills[$name])" }
        $to = Join-Path $skillsDir $name
        # Remove first: Copy-Item onto an existing folder nests the source
        # inside it, and files deleted upstream would survive.
        if (Test-Path $to) { Remove-Item $to -Recurse -Force }
        Copy-Item $from $to -Recurse
        foreach ($f in $src.LicenseFiles) { Copy-Item (Join-Path $clone $f) $to }
        Write-Host "  -> $name"
    }
}

# Dependency closure. A reference is a quoted or backticked skill name
# ("grilling", `ultracave`), a slash command (/caveman-compress), or a
# relative path into another skill folder (../codebase-design/).
$shipped = @(Get-ChildItem $skillsDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object { $_.Name })
$open = 0
foreach ($s in $shipped) {
    $text = (Get-ChildItem (Join-Path $skillsDir $s) -Recurse -File -Filter *.md | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    foreach ($n in ($catalog | Sort-Object -Unique)) {
        if ($n -eq $s -or $shipped -contains $n -or @($manifest.Acknowledged[$s]) -contains $n) { continue }
        $pattern = '(?:[`"]{0}[`"]|(?<![\w.-])/{0}(?![\w-])|\.\./{0}/)' -f [regex]::Escape($n)
        if ($text -cmatch $pattern) {
            Write-Warning "$s references '$n', which is not shipped"
            $open++
        }
    }
}
if ($open) { throw "$open open skill reference(s): vendor the skill, or acknowledge it in skills/vendor.psd1 with the reason" }
Write-Host "Closure OK: $($shipped.Count) skills; every referenced skill is shipped or acknowledged."
