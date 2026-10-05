# Skills overhaul: retire superpowers, add mattpocock + caveman, ship every skill in-repo

Date: 2026-10-05 · Author: @boss · Lane: PIPELINE, 6 tasks, one commit
each (Task 6 is run by the user: agents may not write `~/.config/kilo`
or `~/.kilo`).

## Context

### The request

> I want to reduce the skills and want to keep ponytail, add a new skill
> caveman and skills from https://github.com/mattpocock/skills. I will
> take out superpowers and any other skills you feel like are not
> required now. I also want that any dependency between skills are also
> shipped with my repo.

### Where the pool stands today

- 15 skills in `~/.kilo/skills`: 9 from obra/superpowers, 2 from
  DietrichGebert/ponytail, 3 from anthropics/skills, all cloned at install
  time (`install.ps1:57-94`, `install.sh:47-72`) from two hand-synced
  lists (`scripts/update-skills.ps1:13-21`, `install.sh:67-72`), plus the
  local `skills/codebase-map/`.
- Nothing ever removes a skill dropped from those lists: neither installer
  nor `update-skills.ps1` deletes, and agents cannot (bash denies
  `Remove-Item`/`rm`; edits under `~/.kilo/**` are denied).
- 8 of the 9 superpowers skills clash with the harness, 5 structurally:
  writing-plans (wrong plan format and path, human-review handoff),
  executing-plans and subagent-driven-development (a competing pipeline),
  dispatching-parallel-agents (the conductor forbids parallel workers),
  requesting-code-review (a general-purpose reviewer the conductor
  forbids). The ninth, verification-before-completion, restates
  `config/instructions.md:91-106`.
- Only `codebase-map` is named in agent prompts. The other 14 are reached
  through one row each of the table at `config/instructions.md:73-89`.
- Always-loaded description weight of the current pool: 3,882 chars.

### Research: mattpocock/skills

- MIT (Copyright (c) 2026 Matt Pocock). HEAD `e47c149` (2026-10-05,
  "Added experimental chief-of-staff skill"). HEAD moved between a
  `git ls-remote` and a clone during this research (`f6abdeb` -> `e47c149`):
  the repo commits daily.
- 38 skills in four folders: engineering (20), productivity (7), misc (4),
  in-progress (7).
- Design: model-invoked skills carry trigger descriptions; user-invoked
  ones set `disable-model-invocation: true`
  (`skills/productivity/writing-for-agents/SKILL-MECHANICS.md`,
  "Invocation"). Skills compose with `Call the Skill tool with "X"`. Every
  folder also carries `agents/openai.yaml` (Codex metadata, ignored by
  Kilo).
- The main flow (`skills/engineering/ask-matt/SKILL.md`): grill-with-docs
  -> (prototype) -> to-spec -> to-tickets -> implement / implement-spec
  (tdd + code-review) -> retro. The middle of that flow runs on an issue
  tracker configured by setup-matt-pocock-skills
  (`docs/agents/issue-tracker.md` in the target repo).

### Research: caveman (JuliusBrussee/caveman)

- An output-voice skill: "Terse caveman voice: answer first, fluff gone,
  every technical fact kept", on until "stop caveman" / "normal mode",
  with plain-prose exceptions for security warnings, irreversible
  actions, and anything persisted outside chat
  (`skills/caveman/SKILL.md:72-81`).
- ponytail already points at it: "Ponytail governs what you build, not how
  you talk (pair with Caveman for terse prose)"
  (`~/.kilo/skills/ponytail/SKILL.md:116`). Adding caveman closes the only
  cross-skill pointer the kept ponytail skills have.
- The repo is now a product suite (CLI, local proxy, Caveman Cloud
  gateway, 22 skills). HEAD `6571943` (2026-10-04). Apache-2.0 since
  3.0.0 with a root NOTICE, plus pre-3.0 MIT contributions whose notice
  must travel (`LICENSING.md:3-4`, `:38-40`). "Caveman" is a trademark:
  naming the project is fine, implying an official distribution is not
  (`TRADEMARKS.md`).
- Honest numbers (`docs/HONEST-NUMBERS.md:16-18`, `:32-39`;
  `skills/caveman/README.md:10`): against a plain "Answer concisely."
  control, caveman cuts output 3% at the median (inside the noise),
  ultracave 35%, megacave 9% (n=10, single run, output length only). Input
  reduction 0%; the rules add input tokens; one user measured a net loss
  (issue #145).
- Its Kilo integration (`agents/profiles/kilo.json`) is not a skill
  install: it injects `KILO_CONFIG_CONTENT` that routes every request
  through the Caveman local proxy or Caveman Gateway and sets
  `enabled_providers: ["caveman"]`, replacing this config's whole provider
  setup. Out of scope: vendor the skill folders only, never run caveman's
  installer.

### Kilo 7.8.3 mechanics, verified this session

1. `disable-model-invocation` is ignored. The installed `kilo.exe`
   (`<npm root -g>/@kilocode/cli/node_modules/@kilocode/cli-windows-x64/bin/`)
   contains 0 occurrences of `disable-model-invocation`,
   `disableModelInvocation`, or `user-invocable`. Every user-invoked
   upstream skill is model-visible to every agent.
2. Skills are filtered per agent by permission. Binary:
   `available = skills.filter(s => evaluate("skill", s.name, agent.permissions).effect !== "deny")`.
   A denied skill is withheld from `<available_skills>` and cannot load.
3. Skills double as slash commands: Kilo builds a command per skill
   (`source:"skill"`, template = the skill body plus its base directory),
   so `/grill-with-docs` works in the TUI. `argument-hint` is ignored
   (0 hits).
4. Merge order, probed with a transient `KILO_CONFIG_CONTENT` overlay and
   `kilo debug agent`: a global
   `"skill": {"*": "allow", "grilling": "deny", "grill-with-docs": "deny"}`
   resolves to `* allow, grilling deny, grill-with-docs deny` for worker
   and conductor; an agent-level `skill: allow` on quick appends a
   trailing `* allow`, so the last match re-allows everything there.
5. `KILO_CONFIG_DIR=<dir>` layers a directory's `kilo.jsonc` and
   `agents/*.md` over the installed config (probed: an overlay
   `agents/quick.md` replaced quick's description and merged its
   permissions). That lets Task 4 check the repo's edited config with
   `kilo debug agent` before anything is installed.

### Decision: what replaces what

Retire 11, keep 4, add 11. The pool stays at 15 skills.

| Retired | Replacement | Why |
|---|---|---|
| test-driven-development | `tdd` (+ `codebase-design`) | Same red-green loop, plus `tests.md` (good vs bad tests) and `mocking.md` (mock at system boundaries only). No "ask your human partner" exceptions. "Refactoring is not part of the loop. It belongs to the review stage" (`SKILL.md:38`) matches this harness, where review is the verifier's job. |
| systematic-debugging | `diagnosing-bugs` | Refuses to theorise until one command goes red on the bug, then fixes with a regression test: the reproduce-first rule of `instructions.md:96-97`, with a human-in-the-loop script template for bugs only a human can trigger. Its two "ask the user" dead ends (`SKILL.md:16`, `:55`) become reported blockers under `instructions.md:9-11`. |
| verification-before-completion | none | Restates `instructions.md:91-106`, which every agent already loads, and the verifier gates enforce it. |
| writing-plans | none | `worker.md` and `planner.md` own the plan format. The attended "sharpen the design first" step that superpowers left to its uninstalled brainstorming skill is now `grill-with-docs`. |
| executing-plans | none | The conductor plus worker `task_id` resumes. |
| subagent-driven-development | none | The conductor. |
| dispatching-parallel-agents | none | The conductor's explore/general fan-out. The one legitimate parallel pattern (3+ alternative interfaces) lives on in `codebase-design/DESIGN-IT-TWICE.md`. |
| requesting-code-review | none | The conductor's TASK block to @verifier / @verifier-lite; `ponytail-review` for over-engineering. mattpocock's `code-review` is rejected (below). |
| receiving-code-review | none | `worker.md:99-101`. |
| skill-creator | `writing-for-agents` | skill-creator's eval loop needs Claude Code (`claude -p`, `nohup`, `/tmp`). writing-for-agents is the reference for exactly what this repo is made of: skills, AGENTS.md, agent prompts. |
| webapp-testing | none | The Playwright MCP (`config/kilo.jsonc:107-112`) does interactive browser testing; the skill's Python scripts and `/tmp` paths predate it. |

Kept: `codebase-map` (local; 9 agent prompts name it), `ponytail`,
`ponytail-review` (kept with ponytail: same upstream, already wired into
the instructions table), `frontend-design` (no replacement, no conflicts,
204 chars).

Added without a predecessor:

- `grilling` + `grill-with-docs` + `domain-modeling`: an attended design
  interview that leaves `GLOSSARY.md` and ADRs behind, which `tdd` and
  `diagnosing-bugs` read ("read GLOSSARY.md if it exists").
- `retro`: a post-run review that proposes changes to the agent's
  environment. That environment is this repo. Needs `writing-for-agents`.
- `caveman` + `ultracave` + `megacave`: the voice ponytail pairs with. The
  two variants are hard dependencies of caveman's `/caveman ultra` and
  `/caveman wenyan` aliases (`skills/caveman/SKILL.md:19`). Caveman stays
  on demand, not always-on: its measured gain over a concise control is
  3%, and it adds input tokens.

Rejected from mattpocock/skills:

- `code-review`: points hard at setup-matt-pocock-skills and
  `docs/agents/issue-tracker.md` (`SKILL.md:13`, `:29`), runs two parallel
  sub-agents (`SKILL.md:11`, `:58`) that subagents here cannot spawn, and
  duplicates the verifier gate. Shipping it would drag in
  setup-matt-pocock-skills, which names triage, wayfinder, and
  improve-codebase-architecture in turn.
- `to-spec`, `to-tickets`, `implement`, `implement-spec`, `triage`,
  `wayfinder`, `setup-matt-pocock-skills`: the issue-tracker flow, a
  second planning and execution pipeline beside conductor -> worker ->
  verifier. `implement-spec` runs parallel implementers onto an
  integration branch; this harness runs one worker and commits to main.
- `ask-matt`: a router naming 26 skills, most of which would dangle.
- `wizard`: generates bash wizards that write `gh secret` (denied here).
- `teach`, `to-questionnaire`: niche. `misc/*`: Claude Code hooks, Husky,
  shoehorn, exercise scaffolding. `in-progress/*`: experimental upstream.

Optional, one manifest line each, closure already satisfied: `grill-me`
(-> grilling; add it to the interview gate), `improve-codebase-architecture`
(-> codebase-design, domain-modeling, grilling; add it to the interview
gate), `handoff`, `wait-what`, `prototype`, `pr`, `research` (model-invoked
and writes a Markdown file into the repo, so subagents could litter repos
with it).

Rejected from caveman: everything except caveman, ultracave, megacave.
`cavecrew` delegates to `cavecrew-*` agents Kilo does not have.
`caveman-compress` rewrites memory files such as AGENTS.md into caveman
voice, and this repo's prose is the product. `caveman-commit`,
`caveman-review`, `caveman-help`, `caveman-stats` (Claude Code session
logs), the six Caveman Cloud skills, and its workflow skills
(`lean-build`, `surgical-patch`, `safe-refactor`, `migration`,
`investigate-first`, `verify-and-stop`) overlap ponytail, tdd,
diagnosing-bugs, and the verifiers.

Rejected from ponytail: `ponytail-audit`, `ponytail-debt`,
`ponytail-gain`, `ponytail-help`. Neither kept ponytail skill references
them.

### Dependency closure

A hard dependency is a skill step that loads another skill (`Call the
Skill tool with "X"`, "follow the `X` skill"). A soft reference only
points ("see the `X` skill", an exemption clause). Every hard dependency
ships. A soft reference ships when cheap, otherwise it is acknowledged in
the manifest with its reason. Shipping `code-review` would pull in the
tracker suite.

Evidence: every shipped file was scanned for quoted or backticked skill
names, slash commands, and `../<skill>/` paths against the upstream
catalogs of all four sources (the exact check `sync-skills.ps1` runs).

| Skill | References found | Status |
|---|---|---|
| tdd | `codebase-design` (`SKILL.md:26`, hard); `code-review` (`SKILL.md:38`, soft) | shipped; acknowledged |
| grill-with-docs | `grilling`, `domain-modeling` ("Call the Skill tool twice") | shipped |
| retro | `writing-for-agents` (step 1) | shipped |
| caveman | `ultracave`, `megacave` (`SKILL.md:19`, hard); `/caveman-compress` (`SKILL.md:80`, exemption) | shipped; acknowledged |
| ultracave, megacave | `/caveman`; `/caveman-compress` (exemption) | shipped; acknowledged |
| ponytail | Caveman (`SKILL.md:116`, "pair with") | shipped |
| codebase-map | `"triage"` (kopipasta JSON field, `SKILL.md:140`, `:163`) | false positive; acknowledged |
| codebase-design, diagnosing-bugs, writing-for-agents, domain-modeling, grilling, ponytail-review, frontend-design | none | - |

The dry run of the Task 1 script in a scratch copy confirmed the result:
`Closure OK: 15 skills`. With `codebase-design` moved out it failed with
`tdd references 'codebase-design', which is not shipped`, and with
tdd's acknowledgement removed it failed with
`tdd references 'code-review'`.

### Shipping mechanism: vendor into `skills/`

Decision: copy each third-party skill into `skills/<name>/` with its
upstream license file(s), pinned per source in `skills/vendor.psd1`, and
refreshed by a maintainer-run `scripts/sync-skills.ps1`. The installers
mirror `skills/` into `~/.kilo/skills`.

Why this beats the current clone-at-install model:

1. Closure becomes a property of each commit, checked by the script and
   visible in git, rather than of whatever upstream HEAD is at install
   time. mattpocock's HEAD moved during this research.
2. Supply chain: upstream prompt changes arrive as reviewable diffs.
   `update-skills.ps1:6-7` already warns "skills are prompts, and prompts
   are supply chain".
3. Less code: the clone machinery, both curated lists, and
   `update-skills.ps1` go. The installers keep the copy loop they already
   run for codebase-map.
4. Installs need no network or git for skills.
5. The installers mirror the pool, so a skill dropped from the repo
   leaves every machine on the next install. Stale skills were the
   standing defect of the old model.

Cost: 53 files, 156,756 bytes of Markdown and license text (measured). The
licenses permit it: MIT (mattpocock, ponytail) requires the notice copied
along; Apache-2.0 (caveman, frontend-design) requires LICENSE plus NOTICE.

Rejected alternative: keep cloning, add two repos, pin commits, and teach
both installers nested upstream paths and pruning. That is more code, and
closure stays unenforced.

### The interview gate

grilling and grill-with-docs ask the user questions and wait on decisions.
A Flash worker in plan phase sees "A relentless interview to sharpen a
plan or design" next to `instructions.md:71` ("Check for a relevant skill
before starting"). That is a plausible misfire that returns questions
instead of a plan. Since Kilo ignores `disable-model-invocation`, gate
them by permission:

- a global deny in `kilo.jsonc`;
- `skill: allow` re-opens them in quick, boss, and astra (the attended
  primaries);
- the conductor, which never asks or edits (`conductor.md:39-51`), gets a
  one-line redirect.

retro, ultracave, and megacave stay ungated: they fire only on an
explicit `/command` and never ask.

### Context cost

New pool: 15 skills, 3,884 description chars (today: 15 skills, 3,882
chars). For the conductor and every subagent the gate withholds 258 chars,
leaving 3,626. The count holds because caveman brings 2 hard dependencies
and grill-with-docs brings 2. What drops is overlap and conflict. Further
cuts, if wanted: ponytail-review (-456 chars), frontend-design (-204),
retro (-44).

## Assumptions

- A1. "Shipped with my repo" means the repo installs a skill together
  with every skill it depends on. Vendoring is the recommended way to
  guarantee that. If "installed together" was all that was meant, swap
  Tasks 1-2 for the pinned-clone alternative; Tasks 3-6 barely change.
- A2. "Keep ponytail" includes `ponytail-review` (same upstream, already
  installed and wired into the instructions table).
- A3. "caveman" is the JuliusBrussee/caveman skill that ponytail names:
  skill folders only, not its CLI, proxy, cloud skills, or installer.
- A4. "Not required now": webapp-testing and skill-creator go;
  frontend-design stays.
- A5. Hard dependencies ship; soft references ship when cheap and are
  otherwise acknowledged in `skills/vendor.psd1` with a reason (see
  Dependency closure).
- A6. Interview skills run only in attended primaries (quick, boss,
  astra). The conductor stays a router that never asks.
- A7. ponytail, ponytail-review, and frontend-design stay at the commits
  installed today (`e3ba2aa`, `3337550`). Their vendored copies were
  checked identical to the live copies (CRLF normalized).
- A8. The repo owns `~/.kilo/skills`: the installers remove any skill the
  repo does not ship. The pre-install backup (`~/.kilo.bak-<stamp>`)
  keeps it, and the installer prints each removal.
- A9. Caveman stays on demand. Always-on caveman is a separate decision:
  the measured gain is small, and it would also need testing against the
  pipeline's machine-read reports.

## Tasks

### Task 1 - Vendor manifest, sync script, LF for shell files

- **Goal:** the repo can vendor third-party skills at pinned commits and
  prove dependency closure, reproducibly.
- **Difficulty:** MEDIUM
- **Files:** `skills/vendor.psd1` (new), `scripts/sync-skills.ps1` (new),
  `.gitattributes`
- **Test first:** none. This repo has no harness and must never get one
  (`AGENTS.md:11-14`). The script below was dry-run in a scratch copy of
  the repo (results under Context). Task 2's Verify runs the negative
  closure tests against the real tree.
- **Change:**
  1. Create `skills/vendor.psd1` with exactly:

     ```powershell
     # Third-party skills vendored into skills/<name>/ by scripts/sync-skills.ps1.
     # Edit this file, run the script, review `git diff -- skills`, commit.
     # Never hand-edit a vendored folder: the next sync overwrites it.
     # Drop a skill: delete its line here, then `git rm -r skills/<name>`.
     # Local skills (codebase-map) are not listed; the script never touches them.
     @{
         Sources      = @(
             @{
                 Repo         = 'https://github.com/mattpocock/skills'
                 Commit       = 'e47c149e9489bccd6acb41a1fb420ed68a5067e1'
                 LicenseFiles = @('LICENSE')                        # MIT
                 Skills       = @{
                     'tdd'                = 'skills/engineering/tdd'                 # replaces superpowers test-driven-development
                     'codebase-design'    = 'skills/engineering/codebase-design'     # hard dependency of tdd
                     'diagnosing-bugs'    = 'skills/engineering/diagnosing-bugs'     # replaces systematic-debugging
                     'domain-modeling'    = 'skills/engineering/domain-modeling'     # hard dependency of grill-with-docs
                     'grill-with-docs'    = 'skills/engineering/grill-with-docs'     # attended design interview
                     'retro'              = 'skills/engineering/retro'               # post-run review of the harness
                     'grilling'           = 'skills/productivity/grilling'           # hard dependency of grill-with-docs
                     'writing-for-agents' = 'skills/productivity/writing-for-agents' # replaces skill-creator; hard dependency of retro
                 }
             },
             @{
                 Repo         = 'https://github.com/JuliusBrussee/caveman'
                 Commit       = '6571943370f7c9d4de1946481177ee7b306cd8e8'
                 LicenseFiles = @('LICENSE', 'NOTICE', 'LICENSE-MIT') # Apache-2.0; NOTICE and the pre-3.0 MIT text must travel
                 Skills       = @{
                     'caveman'   = 'skills/caveman'   # terse voice; ponytail says "pair with Caveman"
                     'ultracave' = 'skills/ultracave' # hard dependency of caveman (/caveman ultra)
                     'megacave'  = 'skills/megacave'  # hard dependency of caveman (/caveman wenyan)
                 }
             },
             @{
                 Repo         = 'https://github.com/DietrichGebert/ponytail'
                 Commit       = 'e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156'
                 LicenseFiles = @('LICENSE')                        # MIT
                 Skills       = @{
                     'ponytail'        = 'skills/ponytail'
                     'ponytail-review' = 'skills/ponytail-review'
                 }
             },
             @{
                 Repo         = 'https://github.com/anthropics/skills'
                 Commit       = '33375500bcea98d610eb30ce10ac4e59b89c390d'
                 LicenseFiles = @()                                 # Apache-2.0 LICENSE.txt ships inside the folder
                 Skills       = @{
                     'frontend-design' = 'skills/frontend-design'
                 }
             }
         )

         # References the closure check accepts without shipping the target.
         # Every entry needs its reason.
         Acknowledged = @{
             'tdd'          = @('code-review')      # "see the code-review skill" about refactoring; the review stage here is @verifier / @verifier-lite
             'caveman'      = @('caveman-compress') # named only as an exemption from the voice rules
             'ultracave'    = @('caveman-compress') # same exemption clause
             'megacave'     = @('caveman-compress') # same exemption clause
             'codebase-map' = @('triage')           # kopipasta's "triage" mode in a JSON example, not a skill
         }
     }
     ```

  2. Create `scripts/sync-skills.ps1` with exactly:

     ```powershell
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
     ```

  3. `.gitattributes`: add `*.sh text eol=lf` on a new line after
     `install.sh text eol=lf`. This machine runs `core.autocrlf=true`, so
     a vendored shell template
     (`skills/diagnosing-bugs/scripts/hitl-loop.template.sh`) would
     otherwise check out with CRLF and break under bash.
- **Verify:**
  - `$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts\sync-skills.ps1), [ref]$null, [ref]$e); $e.Count`
    prints `0`.
  - `$m = Import-PowerShellDataFile skills\vendor.psd1; $m.Sources.Count; ($m.Sources | ForEach-Object { $_.Skills.Count } | Measure-Object -Sum).Sum; $m.Acknowledged.Count`
    prints `4`, `14`, `5`.
  - `git diff -- .gitattributes` shows exactly one added line.
- **Done when:** both new files exist with the content above, they parse
  and load cleanly, and `.gitattributes` carries the new line.
- **Commit:** `feat: skills vendor manifest and sync script`

### Task 2 - Vendor the 14 skills

- **Goal:** `skills/` holds all 15 skills with their licenses, and closure
  is proven on the real tree.
- **Difficulty:** EASY
- **Files:** `skills/{tdd,codebase-design,diagnosing-bugs,domain-modeling,grill-with-docs,retro,grilling,writing-for-agents,caveman,ultracave,megacave,ponytail,ponytail-review,frontend-design}/**`
  (new, generated by the script)
- **Test first:** n/a, generated content. The negative closure tests
  need the vendored tree, so they run under Verify.
- **Change:**
  1. Precondition: `(Get-ChildItem skills -Directory).Name` prints only
     `codebase-map`. The vendoring run therefore deletes nothing in the
     repo; every target folder is new.
  2. Run `.\scripts\sync-skills.ps1` with no switches. It needs git
     network access (cloning worked from this machine during research).
- **Verify:**
  - The run prints 14 `  -> <name>` lines and no `RE-PIN` line, and ends
    with `Closure OK: 15 skills; every referenced skill is shipped or acknowledged.`
  - `git status --short -- skills` shows 14 new `?? skills/<name>/`
    entries and nothing under `skills/codebase-map`.
  - Licenses:
    `Get-ChildItem skills -Directory | ForEach-Object { '{0} {1}' -f $_.Name, ((Get-ChildItem $_.FullName -File | Where-Object Name -match '^(LICENSE|NOTICE)').Name -join ' ') }`
    shows:
    - `LICENSE` in every mattpocock and ponytail folder;
    - `LICENSE LICENSE-MIT NOTICE` in caveman, ultracave, and megacave;
    - `LICENSE.txt` in frontend-design;
    - nothing in codebase-map.
  - Kept skills unchanged:
    `foreach ($s in 'ponytail','ponytail-review','frontend-design') { ((Get-Content -Raw "skills\$s\SKILL.md") -replace "`r`n","`n") -ceq ((Get-Content -Raw "$HOME\.kilo\skills\$s\SKILL.md") -replace "`r`n","`n") }`
    prints `True` three times.
  - Negative closure tests. Wrap each throwing run in
    `try { ... } catch { $_.Exception.Message }`: an uncaught throw aborts
    the rest of a chained command line, which skipped a restore step in
    the dry run.
    a. Delete the `'tdd' = @('code-review')` line from `skills/vendor.psd1`.
       Run `.\scripts\sync-skills.ps1 -CheckOnly`. Expect
       `WARNING: tdd references 'code-review', which is not shipped` and
       `1 open skill reference(s): ...`. Restore with
       `git checkout -- skills/vendor.psd1`.
    b. Run `Move-Item skills\codebase-design $env:TEMP\kilo\parked-codebase-design`,
       then `-CheckOnly`. Expect
       `WARNING: tdd references 'codebase-design', which is not shipped`.
       Then `Move-Item $env:TEMP\kilo\parked-codebase-design skills\codebase-design`.
    c. Run `-CheckOnly`. Expect `Closure OK: 15 skills; ...`.
  - `[IO.File]::ReadAllText('skills\diagnosing-bugs\scripts\hitl-loop.template.sh') -match "`r`n"`
    prints `False`.
- **Done when:** every check above holds and the commit contains only the
  14 new folders.
- **Commit:** `feat: vendor mattpocock, caveman, ponytail and frontend-design skills`

### Task 3 - Installers mirror `skills/`; the clone machinery goes

- **Goal:** `install.ps1` and `install.sh` copy exactly `skills/` into
  `~/.kilo/skills`, remove every other skill there plus the clone-era
  leftovers, and no longer need git.
- **Difficulty:** MEDIUM
- **Files:** `install.ps1`, `install.sh`, `scripts/update-skills.ps1`
  (deleted)
- **Test first:** none. There is no harness, and the installers are
  user-run (Task 6). Both replacement blocks below were syntax-checked as
  drafts: PowerShell parser 0 errors, Git Bash `bash -n` exit 0. Neither
  was executed, because both delete directories and agent policy denies
  `Remove-Item`/`rm`.
- **Change:**
  1. `install.ps1:24`: `foreach ($tool in @('git', 'node', 'npm')) {`
     becomes `foreach ($tool in @('node', 'npm')) {`. Nothing in the
     installer calls git any more.
  2. `install.ps1:57-94`, from `# 5. Skill repositories + curated skill set`
     through `& (Join-Path $kiloDir 'update-skills.ps1')`, is replaced by:

     ```powershell
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
     ```

  3. `install.sh:22`: `for tool in git node npm; do` becomes
     `for tool in node npm; do`.
  4. `install.sh:41`: `mkdir -p "$CFG/agents" "$KILO/skill-repos" "$KILO/skills"`
     becomes `mkdir -p "$CFG/agents" "$KILO/skills"`.
  5. `install.sh:47-85`, from `clone_or_pull() {` through the `fi` that
     closes the local-skills block (the line before
     `# kopipasta - the context oracle ...`), is replaced by:

     ```bash
     # skills: ~/.kilo/skills mirrors skills/ in this repo (see install.ps1 step 5)
     POOL="$KILO/skills"
     for d in "$POOL"/*/; do
       [ -d "$d" ] || continue
       name="$(basename "$d")"
       if [ ! -f "$REPO_ROOT/skills/$name/SKILL.md" ]; then
         rm -rf "$d"
         echo "  removed $name (not shipped by this repo)"
       fi
     done
     for s in "$REPO_ROOT"/skills/*/; do
       [ -f "$s/SKILL.md" ] || continue
       name="$(basename "$s")"
       rm -rf "$POOL/$name"
       mkdir -p "$POOL/$name"
       cp -r "$s". "$POOL/$name/"
       echo "  -> $name"
     done
     # leftovers of the clone-based installer (before 2026-10-05)
     rm -rf "$KILO/update-skills.ps1" "$KILO/local-skills" "$KILO/skill-repos"
     ```

  6. `git rm scripts/update-skills.ps1`. If policy blocks it, leave the
     file and report that the user must delete it.
- **Verify:**
  - `$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path install.ps1), [ref]$null, [ref]$e); $e.Count`
    prints `0`.
  - `& 'C:\Program Files\Git\bin\bash.exe' -n install.sh; $LASTEXITCODE`
    prints `0`.
  - `git grep -n -e update-skills -e skill-repos -e local-skills -e superpowers -e anthropic-skills -- install.ps1 install.sh`
    matches only the leftover-cleanup lines (the comment and the cleanup
    statement in each file).
  - `git grep -n -E "\bgit (clone|pull|-C)" -- install.ps1 install.sh`
    matches nothing.
  - `Test-Path scripts\update-skills.ps1` prints `False`.
- **Done when:** both installers carry the blocks above, parse cleanly,
  and contain no clone logic; `update-skills.ps1` is gone.
- **Commit:** `feat: installers mirror skills/, retire skill clones`

### Task 4 - Interview gate, skill table, caveman guard

- **Goal:** interview skills load only in attended primaries, the
  instructions table names the new skills, and caveman never compresses
  pipeline traffic.
- **Difficulty:** MEDIUM
- **Files:** `config/kilo.jsonc`, `config/agents/quick.md`,
  `config/agents/boss.md`, `config/agents/astra.md`,
  `config/agents/conductor.md`, `config/instructions.md`
- **Test first:** before editing, run the Verify overlay command against
  the unedited repo. worker shows no `skill` rules: that is the red
  state.
- **Change:**
  1. `config/kilo.jsonc:74-75` (the two comment lines starting
     `// Skills load from ~/.kilo/skills`) become:

     ```jsonc
       // Skills: ~/.kilo/skills mirrors skills/ in this repo (the installers
       // copy it; pins and licenses in skills/vendor.psd1). Interview skills
       // are gated in permission.skill below.
     ```

  2. `config/kilo.jsonc`: after `"doom_loop": "deny",` (line 148) insert:

     ```jsonc

         // Interview skills ask the user and wait on decisions, so only the
         // attended primaries (quick, boss, astra) re-allow them in their own
         // frontmatter. Kilo ignores the upstream disable-model-invocation flag
         // (absent from the 7.8.3 binary); a denied skill is withheld from
         // <available_skills>, so permission is the only gate.
         "skill": { "*": "allow", "grilling": "deny", "grill-with-docs": "deny" },
     ```

  3. `config/kilo.jsonc:233`: delete the line
     `"~/.kilo/skill-repos/**": "allow",`. Task 3 removes that directory.
  4. `config/agents/quick.md`: append to the frontmatter comment block
     (after the line ending `quick is attended by definition.`):

     ```yaml
     # skill: allow re-opens the interview skills (grilling, grill-with-docs)
     # that kilo.jsonc denies globally - quick is attended.
     ```

     Then add `  skill: allow` under `permission:`, after
     `  plan_exit: deny` and before `  task:`.
  5. `config/agents/boss.md` and `config/agents/astra.md`: append to each
     frontmatter comment block (after the line ending
     `The pipeline agents stay the conductor's to dispatch.`):

     ```yaml
     # skill: allow re-opens the interview skills (grilling, grill-with-docs)
     # that kilo.jsonc denies globally; when the conductor dispatches this
     # agent, the conductor's deny cascades over it, as with question.
     ```

     Then add `  skill: allow` under `permission:`, after
     `  plan_exit: deny` and before `  task:`.
  6. `config/agents/conductor.md`: after line 51 (`user can redirect you
     before any model-minutes are spent.`), insert a blank line and:

     ```markdown
     Interview skills (grilling, grill-with-docs) are withheld from you. If the
     user invokes one, tell them to switch to @quick, @boss, or @astra (Tab)
     and stop.
     ```

  7. `config/instructions.md:7-11`: append to the paragraph, after
     `...the verifier's verdict replaces sign-off.`:

     ```markdown
     The one exception is an interview the user starts in @quick, @boss, or
     @astra (grilling, grill-with-docs): there, asking is the job - one round
     per turn.
     ```

  8. `config/instructions.md:73-89`: replace the table with:

     ```markdown
     | Situation | Skill |
     |---|---|
     | Exploring a repo, locating a symbol, sizing a change | codebase-map |
     | Writing ANY code - default posture, laziest working solution | ponytail |
     | Reviewing a change for over-engineering | ponytail-review |
     | Writing or changing behaviour | tdd |
     | Shaping a module's interface or seam | codebase-design |
     | Something is broken and the cause is not obvious | diagnosing-bugs |
     | Writing or editing a skill, AGENTS.md, or an agent prompt | writing-for-agents |
     | Naming domain terms, GLOSSARY.md, or an ADR | domain-modeling |
     | Building UI | frontend-design |

     `/grill-with-docs`, `/retro`, and `/caveman` (with `/ultracave`,
     `/megacave`) run when the user types them. Caveman shapes replies to the
     user only: briefs, receipts, FACTS blocks, VERDICT lines, and files stay
     in plain prose and exact format.
     ```

- **Verify:** overlay the repo config without installing anything.
  `KILO_CONFIG_DIR` layers `config/kilo.jsonc` and `config/agents/*.md`
  over the live config (probed this session):

  ```powershell
  $env:KILO_CONFIG_DIR = (Resolve-Path config).Path
  foreach ($a in 'worker','conductor','coder','quick','boss','astra') {
      $o = kilo debug agent $a 2>$null | Out-String | ConvertFrom-Json
      "$a : " + (($o.permission | Where-Object permission -eq 'skill' | ForEach-Object { "$($_.pattern)=$($_.action)" }) -join ' ')
  }
  (kilo debug agent conductor 2>$null | Out-String | ConvertFrom-Json).prompt -match 'Interview skills \(grilling, grill-with-docs\) are withheld'
  $env:KILO_CONFIG_DIR = $null
  ```

  Expected output:
  - worker, conductor, coder:
    `*=allow grilling=deny grill-with-docs=deny`
  - quick, boss, astra: the same, then a trailing `*=allow`
  - the conductor prompt check prints `True`

  `kilo debug agent` failing to parse means `kilo.jsonc` is broken; fix
  that before committing.
- **Done when:** the overlay shows the expected rules, and the three
  prose edits read as written above.
- **Commit:** `agents: gate interview skills to attended primaries; new skill table`

### Task 5 - README and AGENTS.md

- **Goal:** the docs describe the vendored pool, how it updates, and how
  to use the attended skills.
- **Difficulty:** EASY
- **Files:** `README.md`, `AGENTS.md`
- **Test first:** n/a (prose).
- **Change:**
  1. `README.md:107-111` (from `The installer backs up` through
     `the env-var commands for your keys. Then verify:`) becomes:

     ```markdown
     The installer backs up any existing `~/.config/kilo` and `~/.kilo` before
     touching them, installs the CLI, copies this config, mirrors `skills/`
     into `~/.kilo/skills` (removing any skill this repo no longer ships),
     installs `kopipasta` (via `uv` or `pip`, best effort), and prints the
     env-var commands for your keys. Then verify:
     ```

  2. `README.md`: in the Usage code block, after the two astra lines
     (`:145-146`) and before the closing fence, insert:

     ```text

     # sharpen a design by interview first (attended agents only)
     #   /grill-with-docs   in @quick (cheap) or @boss / @astra (deep)

     # after a run: what should change in the harness itself?
     #   /retro

     # terse replies until "stop caveman"
     #   /caveman           (/ultracave or /megacave compress harder)
     ```

  3. `README.md:153-154` (`Update skills later with: ...`) becomes:
     `Skills update with the repo: \`git pull\`, then re-run the installer.`
  4. `README.md:283-290`, the "What's in the box" block, becomes:

     ```text
     config/kilo.jsonc          global config: models, providers, permissions, MCP, compaction
     config/instructions.md     standing instructions injected into every agent
     config/agents/*.md         the ten agents (system prompt + permissions each)
     skills/                    every skill the harness loads (vendored + local codebase-map)
     skills/vendor.psd1         upstream repo, pinned commit, license files per vendored skill
     scripts/sync-skills.ps1    re-vendors skills from vendor.psd1, checks dependency closure
     install.ps1 / install.sh   one-shot setup
     ```

  5. `README.md:292-308`, the whole "## Skills" section body, becomes:

     ```markdown
     Every skill the harness loads ships in `skills/`. The installers mirror
     that folder into `~/.kilo/skills` and remove anything else there (the
     pre-install backup keeps it), so to keep a skill of your own, add it to
     `skills/`. Third-party skills are vendored byte-for-byte at the commits
     pinned in `skills/vendor.psd1`, each folder with its upstream license:

     - [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) -
       `tdd`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`,
       `grilling`, `grill-with-docs`, `retro`, `writing-for-agents`
     - [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
       (Apache-2.0, NOTICE included) - `caveman`, `ultracave`, `megacave`;
       the skill folders only, not the Caveman CLI, proxy, or gateway
     - [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
       (MIT) - `ponytail`, `ponytail-review`
     - [anthropics/skills](https://github.com/anthropics/skills)
       (Apache-2.0) - `frontend-design`

     Plus one local skill (MIT, same as the config): `codebase-map` - map a
     repository's symbols with
     [kopipasta](https://github.com/mkorpela/kopipasta) before reading files,
     so exploration costs one command instead of a fan-out of reads.

     Every skill a shipped skill depends on ships too, and
     `scripts/sync-skills.ps1` re-checks that on every sync. Kilo ignores the
     upstream `disable-model-invocation` flag, so the interview skills
     (`grilling`, `grill-with-docs`) are gated by permission instead: only
     @quick, @boss, and @astra can load them.

     Refreshing vendored skills (maintainers): run
     `./scripts/sync-skills.ps1 -Latest`, review `git diff -- skills`, paste
     the printed commits into `skills/vendor.psd1`, and commit.
     ```

  6. `README.md:312-313` (`MIT - see [LICENSE](LICENSE). The skill
     collections above ...`) becomes:

     ```markdown
     MIT - see [LICENSE](LICENSE). Vendored skills under `skills/` keep their
     upstream licenses (MIT or Apache-2.0); each vendored folder carries its
     license file(s).
     ```

  7. `AGENTS.md:6-10`, the first bullet, becomes:

     ```markdown
     - This repo is prose and configuration: the Kilo CLI global config
       (`config/kilo.jsonc`), standing instructions (`config/instructions.md`),
       agent prompts (`config/agents/*.md`), installers, and every skill the
       harness loads (`skills/`). Nothing here executes at runtime except the
       installers and the maintainer-run `scripts/sync-skills.ps1`.
     - `skills/` holds vendored third-party skills (byte copies at the
       commits pinned in `skills/vendor.psd1`) plus the local `codebase-map`.
       Never hand-edit a vendored folder - the next sync overwrites it; adapt
       the harness around a skill in `config/` instead.
     ```

- **Verify:**
  - `git grep -n -e update-skills -e superpowers -e skill-repos -e local-skills -e curated -- README.md AGENTS.md config`
    matches nothing.
  - Read the rendered README Skills section once: four sources, 15 skill
    names, the gate sentence.
- **Done when:** the diff matches the text above and the grep is empty.
- **Commit:** `docs: vendored skills, attended skill usage`

### Task 6 - Install and live check (the user runs the installer)

- **Goal:** the harness on this machine runs the new pool with the gate in
  force.
- **Difficulty:** EASY
- **Files:** none. Only the plan status changes.
- **Test first:** n/a.
- **Change:** the USER runs `.\install.ps1` from the repo root. Agents may
  not write `~/.config/kilo` or `~/.kilo` (`config/instructions.md`,
  "Non-negotiable"). Then restart any open kilo TUI.
- **Verify:** steps 1-5 are read-only checks plus two cheap Flash calls;
  step 6 is manual.
  1. `(Get-ChildItem ~\.kilo\skills -Directory).Name | Sort-Object` prints
     exactly: caveman, codebase-design, codebase-map, diagnosing-bugs,
     domain-modeling, frontend-design, grill-with-docs, grilling, megacave,
     ponytail, ponytail-review, retro, tdd, ultracave, writing-for-agents.
  2. `Test-Path ~\.kilo\update-skills.ps1, ~\.kilo\local-skills, ~\.kilo\skill-repos`
     prints `False` three times.
  3. `kilo debug skill 2>$null | Out-String | ConvertFrom-Json | ForEach-Object name | Sort-Object`
     prints the same 15 names plus the built-in `kilo-config`.
  4. The Task 4 rule loop, run without the `KILO_CONFIG_DIR` overlay,
     prints the same expected rules.
  5. Run
     `kilo run --agent quick "List the skill names in your available_skills block, comma-separated, nothing else."`.
     The list includes grilling and grill-with-docs. The same prompt with
     `--agent conductor` lists neither but includes the other 13 and
     kilo-config.
  6. Manual, in the TUI: `/grill-with-docs <a small design question>` in
     @quick starts the interview with a question. In the conductor, the
     same command gets the redirect line.
- **Done when:** steps 1-5 match and the user confirms step 6.
- **Commit:** none.

## Risks

1. **Model-visible user commands.** Kilo ignores
   `disable-model-invocation` (verified), so `retro`, `ultracave`, and
   `megacave` are visible to every agent (423 description chars). Their
   descriptions ("Invoke only with /ultracave or /caveman ultra") and the
   instructions sentence should hold them. If one misfires, add it to the
   global deny next to the interview skills.
2. **Denied skills as slash commands.** It is unknown whether Kilo lists a
   permission-denied skill as a command in the conductor's TUI. The
   redirect line covers both cases; Task 6 step 6 settles it.
3. **Interview quality.** In @quick the interview runs on Flash. Use
   @boss or @astra for designs worth a frontier model. grilling's "dispatch
   a sub-agent to find facts" runs inline in quick, which cannot delegate.
4. **Upstream drift.** mattpocock/skills moved during this research. Pins
   plus the closure check make updates a deliberate `-Latest` run with a
   reviewed diff, never something that happens at install time.
5. **Caveman.**
   - The measured gain over a concise control is 3% (35% for ultracave),
     and the rules add input tokens, so it stays on demand (A9).
   - Never run caveman's installer or apply its Kilo profile: it replaces
     every provider with the Caveman proxy or gateway.
   - The guard sentence (briefs, receipts, FACTS, VERDICT stay plain) has
     not been exercised in a live PIPELINE run with caveman on.
6. **Pool mirroring.** The installer removes any skill the repo does not
   ship. The backup keeps it and the installer prints each removal, but a
   hand-installed skill drops out of the live pool until it is added to
   `skills/`.
7. **Possible edit block on `config/kilo.jsonc`.** The edit and write deny
   pattern `kilo.jsonc` could block that file. Past sessions edited it
   unblocked; not re-tested. If blocked, stop and hand the exact Task 4
   edit to the user.
8. **`git rm` may be denied** by the bash policy (Task 3 step 6). If so,
   the user deletes `scripts/update-skills.ps1`.
9. **Agent-run syncs.** Later syncs delete and recopy existing vendored
   folders inside the script. Agents should run only `-CheckOnly` or a
   first-time vendoring like Task 2; refreshes are the maintainer's call.
10. **Line endings.** `*.sh text eol=lf` keeps the vendored shell template
    runnable. Markdown and psd1 files checking out with CRLF on Windows is
    harmless.
11. **tdd's code-review pointer** dangles by design (acknowledged). An
    agent following it fails to find `code-review` and moves on; the review
    stage here is the verifier.
12. **No net reduction.** The count stays at 15 and context stays flat.
    The gain is zero pipeline-competing skills. Cut levers are listed under
    Context cost.
13. **Licenses and trademark.**
    - Every vendored folder carries its notices.
    - The README attributes each source.
    - Nothing claims to be an official Caveman distribution.
14. **Out of scope, still open from the earlier repo review:**
    - `README.md:98` says 7.7.1 while the installers pin 7.8.1.
    - The Playwright MCP tools are unrestricted, verifiers included.
    - `instructions.md:56-61` contradicts `worker.md` on plan detail.

PLAN COMPLETE
