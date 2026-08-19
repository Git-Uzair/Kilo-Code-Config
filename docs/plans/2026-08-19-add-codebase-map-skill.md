# Add the `codebase-map` (kopipasta) skill to the Kilo config repo

## Context

- Repo: `.` (repo root) - a **configuration repo**, no source
  code. Contents verified this session: `install.ps1` (101 lines),
  `install.sh` (88 lines), `scripts/update-skills.ps1` (34 lines),
  `config/kilo.jsonc` (177), `config/instructions.md` (148),
  `config/agents/{conductor,planner,coder,opus-coder,verifier}.md`,
  `README.md` (187), `LICENSE`, `.gitignore`, `.gitattributes`.
- **No manifest and no test harness** (no `package.json`, `pyproject.toml`,
  `Makefile`, CI workflow - `Get-ChildItem -Recurse` this session lists every
  file above and nothing else). There is therefore no `npm test` /
  `pytest` to run. Verification for this repo is **syntax + behaviour checks
  on the two installers**, run this session and proven to work:
  - PowerShell parse (no execution):
    ```powershell
    $errs=$null; $toks=$null
    [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\install.ps1).Path,[ref]$toks,[ref]$errs) | Out-Null
    "ps errors: " + $errs.Count      # must print: ps errors: 0
    ```
  - Bash parse: `bash -n ./install.sh` -> exit 0 (`bash` on PATH,
    `bash -c "echo ok"` returns `ok`).
- Toolchain present on this machine: `git`, `node`/`npm`, `python`
  (Anaconda), `pip`, `uv` (`~/.local/bin/uv.exe` or on PATH), `bash`.
  `kopipasta` is installed but at **0.69.0**, which predates the verb CLI -
  its `--help` shows only `[-t TASK] [--reset-template] ...`, no `map`/`ask`.
- Verified kopipasta facts (from the **0.70.0 wheel**, downloaded and read
  this session at `<temp>/kilo/kp/x/kopipasta/`;
  0.70.0 is the latest release per `https://pypi.org/pypi/kopipasta/json`):
  - `main.py:201` - `VERBS = ("ask", "apply", "map", "session", "config")`,
    dispatched before the legacy parser (`main.py:403`).
  - `core/map.py:47-83` - `kopipasta map [PATH ...]` with the shared
    selection flags, `--budget SIZE`, `--strict-budget`, `--json`.
  - `core/ask.py:98-155` - the selection grammar is
    **`-e/--edit`, `-r/--ref`, `-m/--map`, `-s/--snippet`, `-x/--exclude`,
    `--all`, `--changed`, `--changed-since REF`, `--from-file PATH`**.
    There is **no `--pin` in any released version** (see Assumptions).
  - `core/ask.py:213-216` - `--dry-run` = "assemble and record everything,
    call no model (same as `--backend none`)"; `core/backend.py:155-186` -
    `NoneBackend` needs no API key.
  - `core/session.py:40-41` - `ask` writes `.kopipasta/sessions/<id>/`.
  - `file.py:582-631` - symbols exist only for `.py/.js/.jsx/.ts/.tsx`;
    every other file renders as a bare path line.
- Constraints that shaped the plan: agents may not edit `~/.kilo/**` or
  `~/.config/kilo/**` (`config/kilo.jsonc:104-117`), `rm`/`Remove-Item` are
  denied to agents (`config/kilo.jsonc:122-124`), and `.gitattributes`
  pins `install.sh` to LF and `*.ps1` to CRLF.

## Assumptions

- `--pin` does not exist in any released kopipasta. The GitHub README (main
  branch) documents `-p/--pin`, but the 0.70.0 wheel - what
  `uv tool install kopipasta` / `pip install kopipasta` actually gets -
  implements `-e/--edit` (`core/ask.py:101-107`). **The skill is written
  against `-e/--edit`** and tells the reader to run `kopipasta ask --help`
  and prefer `--pin` if their build has it. Writing `--pin` as the primary
  form would ship a skill whose every example fails with exit 1.
- Skill lives at **`skills/codebase-map/SKILL.md`** (top-level `skills/`,
  new). `config/` mirrors `~/.config/kilo`, but skills load from
  `~/.kilo/skills` - a different tree - so putting it under `config/` would
  imply the wrong destination.
- Installers mirror the repo's `skills/` tree into `~/.kilo/local-skills/`
  **and** copy it into the pool `~/.kilo/skills/`. The mirror is what makes
  the standalone `~/.kilo/update-skills.ps1` able to refresh local skills
  without knowing where the config repo was cloned.
- The added copy logic uses `Copy-Item <src>\* <dest> -Recurse -Force` /
  `cp -r <src>. <dest>/` rather than delete-then-copy: no destructive op, and
  it sidesteps the `Copy-Item -Recurse` into-an-existing-directory nesting
  quirk that the existing curated loop already suffers (see Risks).
- kopipasta installation is **best-effort, never fatal**: a warning if
  neither `uv` nor `pip` is present. Installing it must not be able to break
  a Kilo install for someone with no Python.
- No test harness is bootstrapped. A pytest/vitest scaffold in a repo of
  markdown prompts and two installers would be pure bloat; the executable
  verification commands per task are the substitute, and each task states
  the exact command and expected output.
- `kopipasta ask` against a real model is **documented but not configured**.
  It needs `~/.config/kopipasta/config.toml` plus `GEMINI_API_KEY` /
  `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` (`core/ask.py` help text;
  `README` of kopipasta) - our config only sets
  `GOOGLE_GENERATIVE_AI_API_KEY` and `AWS_BEARER_TOKEN_BEDROCK`
  (`install.ps1:73-76`). The installers print one guidance line; they do not
  write a kopipasta config file.
- `KiloCode.md` at the repo root is untracked scratch documentation. Leave it
  untracked; never `git add -A`.
- Commit per task on `main` (the repo's default branch), push once at the
  end - the user asked for commit **and** push.

## Task 1 - create the `codebase-map` skill

- **Goal**: add the local skill `skills/codebase-map/SKILL.md` that teaches an
  agent to map a repo with `kopipasta map` before reading files.
- **Difficulty**: `HARD`. It is a prompt, so nothing compiles and nothing
  fails loudly; every flag has to be exactly the released one, and the
  free/paid and writes-nothing/writes-`.kopipasta` distinctions are the
  difference between a useful skill and one that spends money or dirties a
  worktree under a verifier.
- **Files**:
  - `skills/codebase-map/SKILL.md` (NEW; `skills/` directory is new too)
- **Test first**: no harness (see Assumptions). The pre-check that stands in
  for a failing test - run it **before** writing the file and paste the output
  in your report:
  ```powershell
  Test-Path .\skills\codebase-map\SKILL.md     # must print False before, True after
  ```
- **Change**: create the file with **exactly** this content (frontmatter
  format verified against an installed skill,
  `~/.kilo/skills/ponytail/ponytail/SKILL.md:1-18`: `name`,
  block-scalar `description`, optional `license`). Single trailing newline,
  no tabs, no emoji, no non-ASCII:

  ````markdown
  ---
  name: codebase-map
  description: >
    Free AST symbol map of a repository with `kopipasta map` - the first move
    when exploring unfamiliar code, locating where a symbol or behaviour
    lives, checking whether a helper already exists, or sizing which files a
    change touches. Also bundles several files into one payload with
    `kopipasta ask --dry-run` (no model, no cost), and triages a whole repo in
    one call with `kopipasta ask -q "..." --json` when a provider key is
    configured. Use it BEFORE opening files to find out which files matter, on
    any repo you do not already know by heart, and before writing a new helper
    in an unfamiliar module. Do NOT use it as a substitute for reading the
    lines you are about to change or cite.
  license: MIT
  ---

  # Codebase map

  Reading files to discover which files matter spends the context you needed
  them for. `kopipasta map` prints the repository's symbol skeleton locally -
  no model call, no network, no cost, nothing written - so you decide *what to
  read* before you decide *what to pay for*.

  This skill covers three moves. Move 1 is free and safe everywhere. Move 2 is
  free and writes session files. Move 3 spends money and needs a key.

  ## Before anything: two hard rules

  1. **Never run bare `kopipasta`.** With no verb it launches an interactive
     TUI and your shell call never returns. Always name a verb: `map`, `ask`,
     `session`, `config`.
  2. **Export `KOPIPASTA_NONINTERACTIVE=1`** in the same command when you are
     unattended, so anything that would prompt exits instead of waiting.

  Check the tool is the right generation:

  ```powershell
  kopipasta map --help          # PowerShell
  ```
  ```bash
  kopipasta map --help          # bash
  ```

  - First line `usage: kopipasta map` -> good, 0.70.0 or newer.
  - First line `usage: kopipasta` (with `-t TASK`, `--reset-template`) -> too
    old, the verbs do not exist yet.
  - `kopipasta: command not found` -> not installed.

  Install or upgrade:

  ```bash
  uv tool install --force kopipasta     # preferred
  pip install --upgrade kopipasta       # fallback
  ```

  Cannot install it? Say so in your report and fall back to a narrow `glob`
  plus anchored `grep`. Never invent output you did not run.

  Run it from the repository root: the project root is resolved by walking up
  for `.git`, and `.gitignore` is read from the current directory.

  ## Move 1 - map first (free, writes nothing)

  ```bash
  kopipasta map                          # whole repo, text
  kopipasta map src/auth                 # one subsystem
  kopipasta map --json > map.json        # machine-readable, then grep it
  kopipasta map --budget 40k src         # cap the size
  kopipasta map -x 'tests/**' src        # exclude, applied last, wins
  kopipasta map --changed                # only the working-tree changes
  kopipasta map --changed-since main     # only what this branch touched
  ```

  Text output is one line per file, its symbols indented four spaces:

  ```text
  src/auth/tokens.py
      def validate(token: str) -> bool  # Reject expired tokens.
      class TokenStore(Base) [get, put, purge]  # Backing store.
  src/auth/keys.bin
  ```

  A file with no line under it has no extractable symbols - **not** an empty
  file. Symbols are extracted for `.py`, `.js`, `.jsx`, `.ts`, `.tsx` only.
  For Go, Rust, Java, C#, PHP and everything else, `map` still lists the file,
  so the output is a filtered file tree: useful, but not a symbol index. Say
  which you got.

  `--json` gives one object:

  ```json
  {"ok": true, "files": 128, "with_symbols": 96, "symbols": 812,
   "chars": 41233, "est_tokens": 10308,
   "map": {"src/auth/tokens.py": ["def validate(token: str) -> bool  # ..."]},
   "path_only": ["src/big_generated.py"], "unmatched": []}
  ```

  `path_only` lists files the `--budget` demoted: they are still named, with
  no symbols. Nothing is ever silently dropped, and a selector that matched
  nothing is reported rather than ignored.

  **Then read narrowly.** The map names candidates; it is not evidence. Open
  the 2-5 files it points at with the `read` tool, by line ranges, and never
  cite a `path:line` you have not seen. Piping a whole-repo map into your
  context defeats the purpose - for a large repo, redirect to a file and grep
  that file instead:

  ```bash
  kopipasta map --json > map.json
  ```

  ## Move 2 - bundle several files in one call (free, writes `.kopipasta/`)

  When you genuinely need three or more whole files, assemble them in one
  payload instead of N tool calls:

  ```bash
  kopipasta ask -e src/auth/tokens.py -e src/auth/session.py \
                -r 'tests/test_auth*.py' -m 'src/**/*.py' \
                -q "Trace validation to refresh." --dry-run
  ```

  `--dry-run` calls no model and needs no API key (it is `--backend none`).
  Without `--json`, **stdout is the assembled payload itself** - project tree,
  then the files, with `-e/-r` rendered whole, `-m` as skeletons and `-s` as
  first-50-lines. With `--json`, stdout is a receipt and `request` names the
  file to read:

  ```json
  {"ok": true, "session": "2026-08-19-0e5f", "turn": 1, "mode": "triage",
   "request": ".kopipasta/sessions/2026-08-19-0e5f/001-request.md",
   "sent": {"edit": 2, "ref": 3, "map": 380, "demoted": 0},
   "est_input_tokens": 41233, "dry_run": true}
  ```

  Be honest about what this buys: **fewer round-trips and one consistent
  snapshot, not fewer content tokens.** The token saving comes from choosing
  the cheap roles - `-m` skeleton, `-s` snippet - over full content.

  It writes `.kopipasta/sessions/<id>/` into the repository root. You cannot
  delete it (`rm` is denied), so: stage files explicitly, never `git add -A`
  or `git add .`, and mention the leftover directory in your report.

  ## Move 3 - triage a whole repo in one call (costs money, needs a key)

  A separate process with its own large, disposable context reads the repo and
  hands back pointers, so your own context stays clean:

  ```bash
  kopipasta ask --all -q "Where is rate limiting enforced?" --json
  ```

  The default mode is `triage`; the answer carries `hypothesis`,
  `relevant_files` (each with `why` and `confidence`), `suggested_selection`
  (the minimal set to load in full next) and `missing_context` (what the model
  needed and did not get - read it, it is the honest part). Feed it straight
  back:

  ```bash
  kopipasta ask --from-file selection.txt -m 'src/**/*.py' \
                -q "Trace the path from validation to refresh." --json
  ```

  This path is opt-in and unconfigured by default. Confirm before using it:

  ```bash
  kopipasta config --show     # prints what resolved and whether a key is set
  ```

  Needs `~/.config/kopipasta/config.toml` (`[ask] provider/model`) plus
  `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` - note these are
  *not* the variables Kilo itself uses. **Exit 2 means no usable backend: do
  not retry, fall back to Move 1 and say the oracle was unavailable.** Do not
  spend a paid call without a stated reason.

  ## Selectors (shared by `map` and `ask`)

  | Flag | In `ask` | In `map` |
  |---|---|---|
  | `-e, --edit PATTERN` | full content, editable | skeleton |
  | `-r, --ref PATTERN` | full content, read-only | skeleton |
  | `-m, --map PATTERN` | AST skeleton | skeleton |
  | `-s, --snippet PATTERN` | first 50 lines | skeleton |
  | `-x, --exclude PATTERN` | dropped, applied last | dropped |
  | `--all` | every non-ignored file | every non-ignored file |
  | `--changed` | git working tree, incl. untracked | same |
  | `--changed-since REF` | `git diff --name-only REF...HEAD` | same |
  | `--from-file PATH` | newline-delimited paths | same |

  Repeatable and order-independent; the most detailed role wins, so
  `-m '**/*.py' -e src/api.py` skeletons the tree and sends that one file
  whole. Globs, directories and literal paths all work, and `@file` reads
  patterns from a file. `map` renders everything as a skeleton whatever flag
  selected it - that is the verb's whole point. `.gitignore` and binary
  filtering always apply.

  Older builds may name `-e/--edit` as `-p/--pin`. If an example fails with a
  usage error, run `kopipasta ask --help` and use whichever your build shows.

  ## Exit codes

  | Code | Meaning | Do |
  |---|---|---|
  | 0 | success | continue |
  | 1 | usage or configuration error | fix the command, do not retry blind |
  | 2 | no usable backend (no key) | fall back to `map`; never retry |
  | 3 | backend error or timeout | retry once if `--json` says `retryable` |
  | 6 | over `--strict-budget` | narrow the selection |
  | 8 | needed a human, none attached | state what it asked for |

  ## Scope

  - `kopipasta apply` is **not** part of this skill. Kilo's `edit`/`write`
    tools own file mutation; a second patcher is a second way to corrupt a
    file.
  - In a read-only role (verifier), `map` is allowed - it writes nothing and
    calls nothing. `ask` is not: it writes `.kopipasta/` into the tree.
  - The map is a hypothesis generator. Evidence is still a file you read or a
    command you ran.
  ````

  Notes for the executor:
  - The block above is fenced with four backticks so the inner triple-backtick
    fences survive. Write the **inner** content only - do not write the
    four-backtick fence line, and de-indent every line by the two spaces used
    here for nesting.
  - Do not "improve" a flag name. Every flag in it was read out of the 0.70.0
    wheel this session.
- **Done when**:
  - `Test-Path .\skills\codebase-map\SKILL.md` prints `True`.
  - `(Get-Content .\skills\codebase-map\SKILL.md -Raw).EndsWith("`n")` is
    `True` and the file does not end with a blank line
    (`(Get-Content .\skills\codebase-map\SKILL.md)[-1]` is a non-empty line).
  - Frontmatter check passes:
    `(Get-Content .\skills\codebase-map\SKILL.md -TotalCount 2) -join '|'`
    starts with `---|name: codebase-map`.
  - ASCII-only check returns nothing:
    ```powershell
    Select-String -Path .\skills\codebase-map\SKILL.md -Pattern '[^\x00-\x7F]'
    ```
  - No `--pin` outside the one "older builds may name" sentence:
    `(Select-String -Path .\skills\codebase-map\SKILL.md -Pattern '\-\-pin').Count` is `1`.
  - Committed: `git add skills/codebase-map/SKILL.md` then
    `git commit -m "skills: add local codebase-map skill (kopipasta map first, then read)"`.

## Task 2 - `install.ps1`: install kopipasta and the local skill

- **Goal**: the Windows installer mirrors the repo's `skills/` tree into
  `~/.kilo/local-skills/`, copies it into the skill pool, and installs
  kopipasta best-effort.
- **Difficulty**: `EASY`.
- **Files**: `install.ps1` (exists, 101 lines; CRLF per `.gitattributes:3`).
- **Test first**: run the parse check on the unmodified file first so you know
  the baseline is clean, and paste both runs (before and after) in your report:
  ```powershell
  $errs=$null; $toks=$null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\install.ps1).Path,[ref]$toks,[ref]$errs) | Out-Null
  "ps errors: " + $errs.Count       # expect: ps errors: 0
  ```
- **Change**: two insertions. **Do not run `install.ps1`** at any point - it
  does `npm install -g` and overwrites the live `~/.config/kilo`.

  **(a)** Insert the local-skill mirror **between** the `foreach` loop that
  clones the skill repos and the `Copy-Item ... update-skills.ps1` line. The
  anchor is `install.ps1:66-68`:

  ```powershell
      if ($LASTEXITCODE -ne 0) { throw "git failed for $name (exit $LASTEXITCODE)" }
  }
  Copy-Item (Join-Path $repoRoot 'scripts\update-skills.ps1') $kiloDir -Force
  ```

  becomes:

  ```powershell
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
  ```

  Why `Copy-Item <src>\* <dest> -Recurse -Force` into a pre-created directory
  rather than `Copy-Item <src> <dest> -Recurse`: the latter nests
  (`skills\codebase-map\codebase-map\`) when the destination already exists.
  No `Remove-Item` anywhere - it is on the agent deny-list and a delete in an
  installer that runs against `$HOME` is not worth the blast radius.

  **(b)** Insert the kopipasta install as a new step **after** the
  `& (Join-Path $kiloDir 'update-skills.ps1')` line (`install.ps1:68`) and
  **before** the `# 6. API keys` comment block (`install.ps1:70`). Renumber
  the trailing comments: the API-keys step becomes `# 7.` and `# 7. Verify`
  becomes `# 8.` - they are comments only, nothing references them.

  ```powershell
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
  }
  else {
      Write-Warning "kopipasta not installed (needs uv or pip). The codebase-map skill falls back to plain reads until you run: uv tool install kopipasta"
  }
  ```

  Note `uv tool install --force` (verified: `uv tool install --help` on this
  machine offers `--force`/`--reinstall`, there is **no** `--upgrade`).
  `--force` keeps the step idempotent on re-runs.

  **(c)** In the API-keys guidance block, after the `FIRECRAWL_API_KEY` line
  (`install.ps1:76`) and before the Firecrawl parenthetical, add one line -
  kopipasta uses its own variable names:

  ```powershell
  Write-Host '  [Environment]::SetEnvironmentVariable("GEMINI_API_KEY","<optional-key-for-kopipasta-ask>","User")'
  Write-Host "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
  ```
- **Done when**:
  - The parse check above prints `ps errors: 0`.
  - `(Select-String -Path .\install.ps1 -Pattern 'kopipasta').Count` is `>= 4`.
  - The copy logic is proven in isolation against a throwaway destination -
    run exactly this (it touches only the temp dir, never `$HOME`):
    ```powershell
    $t = "$env:TEMP\kilo\skilltest"
    New-Item -ItemType Directory -Force $t | Out-Null
    foreach ($skill in Get-ChildItem .\skills -Directory) {
      $dest = Join-Path $t $skill.Name
      New-Item -ItemType Directory -Force $dest | Out-Null
      Copy-Item (Join-Path $skill.FullName '*') $dest -Recurse -Force
    }
    Get-ChildItem $t -Recurse -File | ForEach-Object { $_.FullName }
    ```
    Expected: exactly one path ending `skilltest\codebase-map\SKILL.md`, and
    **no** `codebase-map\codebase-map\` nesting. Run the same block twice -
    the second run must produce the identical single path (idempotence).
  - Committed: `git commit install.ps1 -m "install: kopipasta + local skills (Windows)"`.

## Task 3 - `install.sh`: same two additions for macOS/Linux

- **Goal**: keep the Unix installer at parity - local skills copied, kopipasta
  installed best-effort.
- **Difficulty**: `EASY`. Independent of Task 2 (different file) - safe to run
  in parallel with it.
- **Files**: `install.sh` (exists, 88 lines; **LF only** per
  `.gitattributes:2` - do not let an editor write CRLF).
- **Test first**: `bash -n ./install.sh` on the unmodified file (expect exit
  0), then again after the edit. Paste both.
- **Change**: three insertions. **Never execute `install.sh`.**

  **(a)** After the `copy_skills anthropic-skills ...` line
  (`install.sh:62`), add the local-skill copy. `set -euo pipefail` is active
  (`install.sh:4`), so every command here must succeed or be guarded:

  ```bash
  # local skills shipped in this repo; mirrored so update-skills.ps1 can
  # refresh them later without knowing where this repo was cloned
  if [ -d "$REPO_ROOT/skills" ]; then
    for s in "$REPO_ROOT"/skills/*/; do
      [ -f "$s/SKILL.md" ] || continue
      name="$(basename "$s")"
      mkdir -p "$KILO/skills/$name" "$KILO/local-skills/$name"
      cp -r "$s". "$KILO/skills/$name/"
      cp -r "$s". "$KILO/local-skills/$name/"
      echo "  -> $name (local)"
    done
  fi
  ```

  `"$s"` from `*/` already ends in `/`, so `"$s".` is `<dir>/.` and copies the
  *contents* - the same non-nesting behaviour as the PowerShell version. The
  `[ -f "$s/SKILL.md" ] || continue` guard also stops the loop body running on
  the literal `*/` if `skills/` is ever empty.

  **(b)** Immediately after that block, the kopipasta install - non-fatal
  under `set -e` because every branch ends in `|| echo`:

  ```bash
  # kopipasta - the context oracle behind the codebase-map skill (best effort)
  if command -v uv >/dev/null 2>&1; then
    uv tool install --force kopipasta || echo "WARN: kopipasta install failed"
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --upgrade kopipasta || echo "WARN: kopipasta install failed"
  else
    echo "WARN: neither uv nor pip3 found - skipping kopipasta. The codebase-map skill needs it: uv tool install kopipasta"
  fi
  ```

  **(c)** In the key guidance, after the `FIRECRAWL_API_KEY` echo
  (`install.sh:69`), add:

  ```bash
  echo '  export GEMINI_API_KEY="<optional-key-for-kopipasta-ask>"'
  echo "  (kopipasta ask only - map and ask --dry-run cost nothing and need no key)"
  ```
- **Done when**:
  - `bash -n ./install.sh` exits 0 (`"exit: $LASTEXITCODE"` prints `exit: 0`).
  - `(Select-String -Path .\install.sh -Pattern 'kopipasta').Count` is `>= 4`.
  - Line endings unchanged: `git diff --stat install.sh` shows only the added
    lines, and
    ```powershell
    (Select-String -Path .\install.sh -Pattern "`r").Count
    ```
    is `0`.
  - Committed: `git commit install.sh -m "install: kopipasta + local skills (Unix)"`.

## Task 4 - `scripts/update-skills.ps1`: re-copy local skills on every update

- **Goal**: an update run refreshes the local `codebase-map` skill instead of
  leaving whatever the last install put there.
- **Difficulty**: `EASY`. Independent of Tasks 2 and 3 (different file).
- **Files**: `scripts/update-skills.ps1` (exists, 34 lines).
- **Test first**: parse check on the unmodified file, then after:
  ```powershell
  $errs=$null; $toks=$null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\scripts\update-skills.ps1).Path,[ref]$toks,[ref]$errs) | Out-Null
  "ps errors: " + $errs.Count       # expect 0 before and after
  ```
- **Change**: insert a local-skills pass **between** the curated `foreach`
  loop and the final listing. The anchor is `scripts/update-skills.ps1:32-34`:

  ```powershell
  }
  Write-Host "`nPool now contains:"
  (Get-ChildItem $pool -Directory).Name
  ```

  becomes:

  ```powershell
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
  ```

  `Split-Path -Parent $pool` resolves to `$HOME\.kilo` from the existing
  `$pool = "$HOME\.kilo\skills"` (`scripts/update-skills.ps1:9`) - no new
  path constant, and it stays correct if `$HOME` moves.

  Also update the header comment (`scripts/update-skills.ps1:1-5`): after the
  line `# ~/.kilo/skills (the only directory Kilo actually loads from).` add:

  ```powershell
  # Local skills mirrored to ~/.kilo/local-skills (shipped in the config repo)
  # are re-copied afterwards, so updating never drops them.
  ```
- **Done when**:
  - Parse check prints `ps errors: 0`.
  - `(Select-String -Path .\scripts\update-skills.ps1 -Pattern 'local-skills').Count` is `>= 2`.
  - The new pass is proven in isolation with fake directories under the temp
    dir (never `$HOME`):
    ```powershell
    $root = "$env:TEMP\kilo\updtest"
    $pool = Join-Path $root 'skills'; $local = Join-Path $root 'local-skills'
    New-Item -ItemType Directory -Force (Join-Path $local 'codebase-map'), $pool | Out-Null
    Copy-Item .\skills\codebase-map\SKILL.md (Join-Path $local 'codebase-map') -Force
    foreach ($skill in Get-ChildItem $local -Directory) {
      $dest = Join-Path $pool $skill.Name
      New-Item -ItemType Directory -Force $dest | Out-Null
      Copy-Item (Join-Path $skill.FullName '*') $dest -Recurse -Force
    }
    Get-ChildItem $pool -Recurse -File | ForEach-Object { $_.FullName }
    ```
    Expected: exactly `...\updtest\skills\codebase-map\SKILL.md`, and the same
    single path after a second run.
  - Committed: `git commit scripts/update-skills.ps1 -m "update-skills: re-copy local skills from ~/.kilo/local-skills"`.

## Task 5 - `config/instructions.md`: map before you read

- **Goal**: every agent learns the skill exists and that mapping precedes deep
  reading - without loosening the existing read-by-ranges or narrow-grep rules.
- **Difficulty**: `HARD`. This file is injected into every agent on every
  request; a bullet that reads as "you may skip reading files" would degrade
  every downstream role, and the grep/ranges discipline must survive verbatim.
- **Files**: `config/instructions.md` (exists, 148 lines).
- **Test first**: capture the baseline so the diff is provably additive:
  ```powershell
  (Get-Content .\config\instructions.md).Count          # expect 148 before
  (Select-String -Path .\config\instructions.md -Pattern 'Search-tool ceiling').Count   # expect 1, must stay 1
  ```
- **Change**: three edits, all additive. Keep the file's style: wrapped at
  ~76 columns, ASCII only, `-` bullets, single trailing newline.

  **(a)** Skills table (`config/instructions.md:40-55`). Insert a row
  immediately **after** the header separator `|---|---|` and before the
  `ponytail` row, so the first thing an agent reads in that table is the
  exploration entry point:

  ```markdown
  | Exploring a repo, locating a symbol, sizing a change | codebase-map |
  ```

  Resulting first three lines of the table body order: `codebase-map`,
  `ponytail`, `ponytail-review`.

  **(b)** Context economy (`config/instructions.md:90-99`). Insert as the
  **first** bullet of that section, before the existing
  `- Conductor: exploration expected to touch more than ~3 files ...`:

  ```markdown
  - Map before you read. In a repo you do not already know, the first
    exploration step is a zero-cost AST skeleton - `kopipasta map <path>`
    (skill: `codebase-map`) - and only then do you open the two to five files
    it pointed at. Reading files to work out which files matter spends the
    context you needed them for. The map narrows the target; it never
    replaces the read: `path:line` claims, edits, and citations still come
    from the file itself, opened by ranges. No kopipasta on PATH? Say so and
    fall back to a narrow `glob` plus anchored `grep`.
  ```

  Leave the two existing bullets, and every word of "Environment
  constraints" (`config/instructions.md:101-117`), untouched. The
  search-tool-ceiling rule and the read-by-ranges rule are unchanged by this
  task - the map is an addition in front of them, not a relaxation of them.

  **(c)** In "Work out how to build and test the project"
  (`config/instructions.md:119-129`) nothing changes. In "Definition of done"
  nothing changes. Stated explicitly so the executor does not go looking for
  more places to edit.
- **Done when**:
  - `(Select-String -Path .\config\instructions.md -Pattern 'codebase-map').Count` is `2`
    (one table row, one bullet).
  - `(Select-String -Path .\config\instructions.md -Pattern 'Search-tool ceiling').Count`
    is still `1`, and `git diff config/instructions.md` shows **no deletions**
    (`git diff --numstat config/instructions.md` reports `0` in the deletions
    column).
  - The table still parses as a table: line count of rows between the header
    and the blank line is 15 (14 existing + 1 new).
  - Committed: `git commit config/instructions.md -m "instructions: map before you read (codebase-map)"`.

## Task 6 - agent prompts: point each role at the map

- **Goal**: planner, conductor, coder, opus-coder and verifier each get the
  one instruction that fits their role, with the free/paid and
  writes-nothing/writes-`.kopipasta` boundaries stated where they matter.
- **Difficulty**: `HARD`. Five prompt files, each with a different failure mode
  if the wording is loose: the planner citing symbols it never opened, the
  verifier dirtying the tree it is forbidden to touch, the coder skipping the
  read-before-edit rule.
- **Files** (all exist):
  - `config/agents/planner.md` (94 lines)
  - `config/agents/conductor.md` (159 lines)
  - `config/agents/coder.md` (56 lines)
  - `config/agents/opus-coder.md` (55 lines)
  - `config/agents/verifier.md` (134 lines)
- **Test first**: baseline line counts, so the diff is provably additive:
  ```powershell
  Get-ChildItem .\config\agents\*.md | ForEach-Object { "$($_.Name): " + (Get-Content $_.FullName).Count }
  # expect: coder.md: 56, conductor.md: 159, opus-coder.md: 55, planner.md: 94, verifier.md: 134
  ```
- **Change**: five edits. Every one is an insertion; delete nothing. Do not
  touch any YAML frontmatter - no permission changes are needed, `bash` is
  `"*": "allow"` (`config/kilo.jsonc:120`) so `kopipasta` already runs
  everywhere, including under the verifier's git-only deny list.

  **(a) `config/agents/planner.md`** - "Role boundary" ends with
  (`planner.md:27-28`):

  ```markdown
  your final message. You cannot delegate (subagents cannot spawn subagents) -
  do your own searching with grep/glob and read matches by targeted ranges.
  ```

  Append a new paragraph directly after it (blank line between):

  ```markdown
  Start with the map, not with grep. `kopipasta map <path>` (skill:
  `codebase-map`) prints the repo's symbol skeleton for free - no model call,
  no cost, nothing written - so one command tells you which files and which
  symbols exist before you spend a single read. Map the subsystem first,
  choose the two to five files that matter, then open those by ranges. The map
  is how you find the file; it is never how you cite one - a `path:line`
  anchor in a plan comes from the file you opened, never from a skeleton.
  ```

  Then add a bullet to "Ground rules", immediately after the first bullet
  (the one ending `write "UNVERIFIED - executor must confirm" next to it.`,
  `planner.md:32-34`):

  ```markdown
  - Anchor your research in a map you actually ran: `kopipasta map` the
    affected directories before reading, and let its output - not a guess -
    decide what you open. `kopipasta map --changed-since <base>` scopes it to
    what a branch touched. A skeleton proves a symbol exists and where; it
    does not prove a signature or a line number, so verify those by reading.
  ```

  **(b) `config/agents/conductor.md`** - routing case 1 (`conductor.md:39-41`)
  currently reads:

  ```markdown
  1. **Question / no code change** - answer it. Use @explore for codebase
     lookups and @general for open-ended research so your own context stays
     small. Do not speculate about code you have not seen; delegate the lookup.
  ```

  Append one sentence to that bullet (same bullet, new wrapped lines):

  ```markdown
     Brief them to start with `kopipasta map <path>` (skill: `codebase-map`) -
     a free symbol skeleton - and to return paths plus conclusions, never file
     dumps.
  ```

  And in "Discipline" (`conductor.md:139-141`), append to the first bullet
  (`Subagent context is disposable; ...`):

  ```markdown
    When you brief @planner or @coder on an unfamiliar repo, say which
    subsystem to map first; a mapped brief costs one command and saves a
    fan-out of reads.
  ```

  **(c) `config/agents/coder.md`** - Loop step 3 (`coder.md:32-34`) ends
  `Reuse existing helpers - search before writing a new one. No new
  dependencies unless the brief grants them.` Insert one sentence after
  `search before writing a new one.`, inside the same numbered item:

  ```markdown
     `kopipasta map <dir>` (skill: `codebase-map`) lists every top-level
     symbol in a subsystem in one free call - a better duplicate check than
     guessing grep patterns.
  ```

  Leave Loop step 1 exactly as it is: "Read every file the brief names before
  changing anything" is not weakened by the map, and the map is not a
  substitute for it.

  **(d) `config/agents/opus-coder.md`** - Method step 1 (`opus-coder.md:35-40`)
  begins `Study the failure history before touching anything: ...`. Append to
  that item:

  ```markdown
     Before reading widely, `kopipasta map` the affected subsystem (skill:
     `codebase-map`) so you spend your reads on the files that matter.
  ```

  **(e) `config/agents/verifier.md`** - after the "Never mutate the working
  tree" paragraph (`verifier.md:42-47`, ends `The live tree stays
  untouched.`), add a new paragraph:

  ```markdown
  `kopipasta map <path>` (skill: `codebase-map`) is safe for you: no model, no
  network, and it writes nothing - it is the cheapest way to check a
  DUPLICATION suspicion, because it lists every top-level symbol in a
  directory in one call. `kopipasta ask` is not safe for you: it writes
  `.kopipasta/` into the tree. Never run it. And a skeleton is not evidence -
  a finding still needs the file read or the command run.
  ```

  Also extend the DUPLICATION audit line (`verifier.md:96-97`):

  ```markdown
  - DUPLICATION file:line - re-implements an existing helper; name the
    original file:line (grep for distinctive strings, or `kopipasta map` the
    neighbourhood, before writing this)
  ```
- **Done when**:
  - Every file gained lines and lost none:
    `git diff --numstat config/agents/` shows a `0` deletions column for all
    five files.
  - `(Select-String -Path .\config\agents\*.md -Pattern 'codebase-map').Count`
    is `6` (planner 2, conductor 2, coder 1, opus-coder 1, verifier 1 - i.e.
    7 if you count the verifier's DUPLICATION line, which mentions
    `kopipasta map` without the skill name; assert `>= 6` and list the hits).
  - `(Select-String -Path .\config\agents\verifier.md -Pattern 'kopipasta ask').Count`
    is `1` and the matched line forbids it.
  - Frontmatter untouched:
    `git diff config/agents/ | Select-String -Pattern '^\+.*permission|^\-'`
    returns nothing.
  - Committed: `git commit config/agents -m "agents: map the repo before reading it (codebase-map)"`.

## Task 7 - `README.md`: document the skill and the new dependency

- **Goal**: a fresh clone tells the truth about what the installer does and
  what ships in the box.
- **Difficulty**: `EASY`. Depends on Tasks 1-4 being in place (it describes
  them).
- **Files**: `README.md` (exists, 187 lines).
- **Test first**: `(Get-Content .\README.md).Count` -> expect 187 before.
- **Change**: four edits.

  **(a)** The installer paragraph (`README.md:68-71`) currently ends
  `installs the curated skill set, and prints the env-var commands for your
  keys.` Change that clause to mention the two new actions - this is the one
  edit in this task that replaces text rather than adding it:

  ```markdown
  The installer backs up any existing `~/.config/kilo` and `~/.kilo` before
  touching them, installs the CLI, copies this config, clones the skill
  repositories, installs the curated skill set plus the local skills in
  `skills/`, installs `kopipasta` (via `uv` or `pip`, best effort), and prints
  the env-var commands for your keys. Then verify:
  ```

  **(b)** After the "Update skills later with ..." paragraph
  (`README.md:97-98`), add:

  ```markdown
  `kopipasta` is optional but assumed by the `codebase-map` skill: without it
  agents fall back to plain reads. Needs Python 3.10+; install by hand with
  `uv tool install kopipasta` (or `pip install kopipasta`) and check with
  `kopipasta map --help`.
  ```

  **(c)** "What's in the box" (`README.md:165-171`) - add one line to the code
  block, after the `scripts/update-skills.ps1` line, keeping the column
  alignment of the existing entries:

  ```text
  skills/codebase-map/       local skill: free AST repo map via kopipasta
  ```

  **(d)** "Skills" section (`README.md:173-182`) - append a sentence after the
  existing upstream list:

  ```markdown
  Plus one local skill shipped in this repo (MIT, same as the config):
  `codebase-map` - map a repository's symbols with
  [kopipasta](https://github.com/mkorpela/kopipasta) before reading files, so
  exploration costs one command instead of a fan-out of reads. Installed to
  `~/.kilo/skills/codebase-map/` and mirrored to `~/.kilo/local-skills/` so
  `update-skills.ps1` can refresh it.
  ```
- **Done when**:
  - `(Select-String -Path .\README.md -Pattern 'kopipasta').Count` is `>= 4`.
  - `(Select-String -Path .\README.md -Pattern 'codebase-map').Count` is `>= 3`.
  - `git diff --numstat README.md` shows deletions `<= 4` (only the reflowed
    installer paragraph from edit (a)).
  - Committed: `git commit README.md -m "docs: document the codebase-map skill and the kopipasta dependency"`.

## Task 8 - smoke-test kopipasta for real, then verify the whole change and push

- **Goal**: prove the commands the skill promises actually run on this machine,
  confirm the tree is clean, and publish.
- **Difficulty**: `HARD`. It is the gate: it upgrades a tool on the host, and
  it is the only step that touches the remote.
- **Files**: `.gitignore` (exists, 4 lines) - one added line. Nothing else.
- **Test first**: the smoke test *is* the test, and step 2 below must be run
  and pasted before any "done" claim.
- **Change / steps**, in order:

  1. **Ignore kopipasta state.** Add one line to `.gitignore` after `*.bak-*`:

     ```text
     .kopipasta/
     ```

     Reason: `kopipasta ask` writes `.kopipasta/sessions/<id>/` into the repo
     root, agents cannot delete it (`rm`/`Remove-Item` denied,
     `config/kilo.jsonc:122-124`), and an accidental `git add -A` would commit
     a session transcript. Commit it with the smoke test.

  2. **Upgrade and smoke-test kopipasta.** The installed version here is
     0.69.0, which has no verbs, so this also proves the installer's chosen
     command works:

     ```powershell
     uv tool install --force kopipasta
     kopipasta map --help          # first line must be: usage: kopipasta map
     kopipasta map --json          # exit 0; JSON with ok/files/est_tokens
     ```

     Expected from `kopipasta map --json` in this repo: `"ok": true`, `files`
     >= 10, and every entry in `map` an **empty** list - this repo has no
     `.py/.js/.ts` files, so there are no symbols to extract, only paths
     (`file.py:601-605`). That is the documented behaviour, not a failure;
     record it as evidence for the skill's "filtered file tree" claim.

     If `uv tool install` puts the shim somewhere not on PATH, or the
     Anaconda `kopipasta.exe` at `<anaconda>\Scripts\kopipasta.exe`
     still shadows it, `Get-Command kopipasta | Select-Object Source` tells you
     which one you ran - report the shadowing rather than fighting PATH, and
     fall back to `pip install --upgrade kopipasta` so the Anaconda copy is
     the upgraded one.

     If the network is unavailable, this step is `NOT RUN`: say exactly that,
     do not claim the commands work, and leave the rest of the task's verdict
     to the checks below.

   3. **Re-run every syntax check:**

      ```powershell
      $errs=$null; $toks=$null
      foreach ($f in @('.\install.ps1', '.\scripts\update-skills.ps1')) {
        [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f).Path,[ref]$toks,[ref]$errs) | Out-Null
        "$f -> " + $errs.Count
      }
      bash -n ./install.sh; "install.sh -> $LASTEXITCODE"
      ```

      All four numbers must be `0`.

   4. **Trailing-newline and encoding audit** on every file this change created
      or modified:

      ```powershell
      $files = @('skills\codebase-map\SKILL.md','install.ps1','install.sh',
                 'scripts\update-skills.ps1','config\instructions.md',
                 'config\agents\planner.md','config\agents\conductor.md',
                 'config\agents\coder.md','config\agents\opus-coder.md',
                 'config\agents\verifier.md','README.md','.gitignore')
      foreach ($f in $files) {
        $raw = [IO.File]::ReadAllText((Resolve-Path $f).Path)
        $nl  = $raw.EndsWith("`n")
        $blank = $raw.EndsWith("`n`n")
        $nonAscii = ($raw -match '[^\x00-\x7F]')
        "$f  newline=$nl  doubleblank=$blank  nonascii=$nonAscii"
      }
      ```

      Required for every row: `newline=True doubleblank=False nonascii=False`.

   5. **Diff audit.** `git status --porcelain` must show only `?? KiloCode.md`
      (pre-existing, untracked, leave it) and, if step 2 ran `ask`, nothing
      under `.kopipasta/` because step 1 ignores it. `git log --oneline -8`
      must show one commit per task, no merges.

   6. **Push.** `git push` - plain, no flags. `git push --force` and
      `git push -f` are denied (`config/kilo.jsonc:126`) and are never the
      answer here. If the push is rejected as non-fast-forward, run
      `git pull --ff-only` and push again; if that fails, stop and report -
      do not rebase or force.
- **Done when**:
  - Step 2's three commands are pasted in the report with their real output,
    or the words `NOT RUN` plus the blocking reason.
  - Steps 3 and 4 print the exact expected values for every row.
  - `git status --porcelain` output is only `?? KiloCode.md`.
  - `git log --oneline -1` matches the pushed remote head:
    `git rev-parse HEAD` equals `git rev-parse @{u}`.
  - Commit for this task: `git commit .gitignore -m "chore: ignore .kopipasta session state"`.

## Risks

- **Flag drift between the wheel and GitHub main.** The released 0.70.0 uses
  `-e/--edit`; kopipasta's GitHub README documents `-p/--pin`. If a future
  release renames it, every `ask` example in the skill fails with exit 1
  (usage error) - which is loud, not silent. Mitigation is already in the
  skill: the "older builds may name `-e/--edit` as `-p/--pin`" sentence plus
  the instruction to run `kopipasta ask --help`. If the executor's installed
  build shows `--pin`, **do not** rewrite the skill's examples; add nothing and
  report the discrepancy - `map`, the primary move, takes neither flag.
- **kopipasta 0.69.0 on the host.** Anything run before the Task 8 upgrade
  will treat `map` as a *file path* and drop into the interactive TUI or the
  legacy prompt builder. Never run `kopipasta` unverified inside a task; the
  `kopipasta map --help` first-line check is the gate. If a shell call hangs,
  that is the TUI - abort the turn (Esc) and re-dispatch, per
  `config/instructions.md:109-117` recovery guidance.
- **The installers must never be executed to "test" this change.**
  `install.ps1` does `npm install -g @kilocode/cli@7.4.22` and overwrites
  `~/.config/kilo`; `install.sh` does the same plus `rm -rf` inside
  `~/.kilo/skills`. Verification is parse-only plus the isolated copy-logic
  runs against `<temp>/kilo/...`. Rollback if
  someone does run one: the installer itself backs up `~/.config/kilo` and
  `~/.kilo` to `.bak-<stamp>` first (`install.ps1:23-31`, `install.sh:19-26`),
  so restore from the newest `.bak-*`.
- **Pre-existing `Copy-Item -Recurse` nesting quirk** in the curated loop
  (`scripts/update-skills.ps1:29`): copying a directory onto an existing
  directory nests it, which is why the installed pool already looks like
  `~/.kilo/skills/ponytail/ponytail/SKILL.md`. Kilo finds `SKILL.md`
  recursively, so it works. **Out of scope - do not fix it in this change.**
  Report it and stop; the new local-skills code avoids the quirk by copying
  `<src>\*` into a pre-created destination.
- **Line endings.** `.gitattributes` pins `install.sh` to LF and `*.ps1` to
  CRLF. An editor that rewrites the whole file will produce a diff full of
  phantom changes. If `git diff install.sh` shows every line modified, discard
  with `git checkout -- install.sh` and redo the edit with a targeted
  string replacement instead of a whole-file write.
- **`.kopipasta/` in other people's repos.** The skill tells agents to prefer
  `map` (writes nothing) and, when they do use `ask`, to stage explicitly and
  report the leftover directory. This repo ignores `.kopipasta/` (Task 8 step
  1); other repos will not, and agents cannot delete it. That is a documented
  consequence, not a bug to engineer around.
- **Paid path is unconfigured.** `kopipasta ask` without `--dry-run` needs
  `GEMINI_API_KEY`/`ANTHROPIC_API_KEY`/`OPENAI_API_KEY` plus
  `~/.config/kopipasta/config.toml`, none of which this change creates. It
  exits 2 ("no usable backend") until the user configures it. The skill says
  exit 2 means fall back to `map` and never retry, so an unconfigured host
  degrades to the free path instead of looping.
- **Prompt bloat.** Six prompt files gain text that ships in every request.
  Every insertion in Tasks 5 and 6 is at most a short paragraph; if the
  executor finds itself writing a section, it has overshot - trim to the
  wording given in the plan verbatim.

PLAN COMPLETE
