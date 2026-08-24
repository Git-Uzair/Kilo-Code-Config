# Updates the global Kilo skill pool.
# Pulls each skill repo, then re-copies the curated skill folders into
# ~/.kilo/skills (the only directory Kilo actually loads from).
# Local skills mirrored to ~/.kilo/local-skills (shipped in the config repo)
# are re-copied afterwards, so updating never drops them.
# Review upstream diffs before running this unattended - skills are prompts,
# and prompts are supply chain.

$ErrorActionPreference = 'Stop'
$repos = "$HOME\.kilo\skill-repos"
$pool  = "$HOME\.kilo\skills"

$curated = @{
    'superpowers'      = @('test-driven-development', 'systematic-debugging',
                           'verification-before-completion', 'writing-plans',
                           'executing-plans', 'subagent-driven-development',
                           'dispatching-parallel-agents', 'requesting-code-review',
                           'receiving-code-review')
    'ponytail'         = @('ponytail', 'ponytail-review')
    'anthropic-skills' = @('frontend-design', 'skill-creator', 'webapp-testing')
}

foreach ($repo in $curated.Keys) {
    $repoPath = Join-Path $repos $repo
    if (-not (Test-Path $repoPath)) { Write-Warning "missing clone: $repoPath"; continue }
    Write-Host "== pulling $repo"
    git -C $repoPath pull --ff-only
    foreach ($skill in $curated[$repo]) {
        $src = Join-Path $repoPath "skills\$skill"
        if (-not (Test-Path "$src\SKILL.md")) { Write-Warning "gone upstream: $repo/$skill"; continue }
        # Remove before copying: Copy-Item onto an existing directory nests the
        # source inside it (skills/<name>/<name>/SKILL.md), and Kilo keeps the
        # first-discovered top-level copy - so updates never took effect.
        # Removing first also purges files deleted upstream.
        $dest = Join-Path $pool $skill
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Copy-Item $src $dest -Recurse
        Write-Host "   -> $skill"
    }
}

# Local skills shipped with the config repo, mirrored to ~/.kilo/local-skills
# by install.ps1/install.sh. Re-copied last so an upstream skill of the same
# name can never shadow a local one, and so an update never drops them.
$local = Join-Path (Split-Path -Parent $pool) 'local-skills'
if (Test-Path $local) {
    Write-Host "== local skills"
    foreach ($skill in Get-ChildItem $local -Directory) {
        $dest = Join-Path $pool $skill.Name
        New-Item -ItemType Directory -Force $dest | Out-Null
        Copy-Item (Join-Path $skill.FullName '*') $dest -Recurse -Force
        Write-Host "   -> $($skill.Name)"
    }
}

Write-Host "`nPool now contains:"
(Get-ChildItem $pool -Directory).Name
