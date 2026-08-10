# Updates the global Kilo skill pool.
# Pulls each skill repo, then re-copies the curated skill folders into
# ~/.kilo/skills (the only directory Kilo actually loads from).
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
        Copy-Item $src (Join-Path $pool $skill) -Recurse -Force
        Write-Host "   -> $skill"
    }
}
Write-Host "`nPool now contains:"
(Get-ChildItem $pool -Directory).Name
