# Make `--json` the default form of `kopipasta map` across this config repo

## Context

- Repo: `.` (repo root) - the *source* of a global Kilo CLI
  config (agent prompts, standing instructions, one local skill, installers).
  Content is Markdown + PowerShell/bash installers. **No manifest, no test
  runner, no linter**: there is no `package.json`, `pyproject.toml`, `Makefile`
  or equivalent anywhere in the tree (verified by listing every file under
  `config/`, `scripts/`, `skills/`, `docs/` plus the repo root). So there is no
  `npm test`, no `pytest`, no `ruff`. The verification harness for this change
  is deterministic `Select-String` assertions plus one real `kopipasta` smoke
  run - both specified per task.
- Tracked files (from `git ls-files`): `.gitattributes`, `.gitignore`,
  `LICENSE`, `README.md`, `config/agents/{coder,conductor,opus-coder,planner,
  verifier}.md`, `config/instructions.md`, `config/kilo.jsonc`, `install.ps1`,
  `install.sh`, `scripts/update-skills.ps1`, `skills/codebase-map/SKILL.md`.
  Branch `main`, clean except untracked `KiloCode.md` and `docs/`. Remote
  `origin` = `https://github.com/Git-Uzair/Kilo-Code-Config.git`.
- Toolchain fact verified this session: `kopipasta` on PATH is
  `~/.local/bin/kopipasta.exe`; `kopipasta map --help` prints
  `usage: kopipasta map [-h] ... [--json] [PATH ...]` - i.e. the verb CLI
  (0.70.0+), and `--json` is documented there as "stdout becomes a single JSON
  object". `kopipasta map --json config` in this repo exits 0 and stdout starts
  with `{`; the `.gitignore detected.` / `kopipasta: 7 files, 0 symbols, ~67
  tokens` lines go to **stderr**, so `kopipasta map --json config 2>$null |
  ConvertFrom-Json` parses and `.ok` is `True`. Keys present in that run:
  `ok, files, with_symbols, symbols, chars, est_tokens, map`.
- Flag order is free: `kopipasta map --json -x 'docs/**' config skills` exits 0
  with `"ok": true`. `kopipasta map --json --changed-since main` (from `main`,
  so zero diff) exits **1** with `{"ok": false, "error": "empty_selection", ...}`
  - an empty selection is a reported error, not a crash.
- `git push` (non-force) is permitted: `config/kilo.jsonc:126-128` denies only
  `git push --force*`, `git push -f*`, `git reset --hard*`, `git clean*`,
  `git filter-branch*`, `git config --global*`.
- Constraint that shapes every task: the executor must **not** touch
  `~/.config/kilo/` or `~/.kilo/` (standing non-negotiable). This repo is the
  source; deployment happens when the *user* re-runs `./install.ps1` (it
  mirrors `skills/` to `~/.kilo/local-skills` and `~/.kilo/skills`,
  `install.ps1:68-75`). The plan therefore changes repo files only and says so
  in the final report.

## Assumptions

- "Make `--json` the default" means: every prescribed *invocation* of
  `kopipasta map` in this repo's prompts, skill and docs is written
  `kopipasta map --json ...`. It does **not** mean patching kopipasta itself,
  adding a wrapper script, or setting an env var (no such env default exists in
  `kopipasta map --help`).
- Two kinds of occurrence deliberately keep no `--json`: (a) the
  version/generation check `kopipasta map --help` and the literal expected
  output line `usage: kopipasta map`, because `--help` is what distinguishes
  0.70.0+ from the pre-verb build; (b) exactly one text-mode example in
  `skills/codebase-map/SKILL.md`, kept to explain what dropping `--json` gives
  a human reader. Every other occurrence gains `--json`.
- `docs/plans/2026-08-19-add-codebase-map-skill.md` is a **historical** plan
  (untracked, already executed). It is not rewritten: plans are a record of
  what was decided then, not live prescription.
- `KiloCode.md` (untracked, 2822 lines of scraped upstream Kilo docs) contains
  no `kopipasta` occurrence and is out of scope. `docs/` stays untracked, as it
  is today - each task stages only the files it names; never `git add -A`.
- No test harness is bootstrapped. Adding pytest/vitest to a Markdown config
  repo would be pure bloat and buys nothing; the "failing test" for each task
  is a `Select-String` assertion that provably lists bare occurrences *before*
  the edit and returns nothing *after* it. Each task states the exact command
  and its expected before/after output.
- Commit style follows existing history (`git log --oneline -5`):
  `instructions: ...`, `agents: ...`, `skills: ...`, `docs: ...`,
  `install: ...`, `chore: ...`. One commit per task, on `main`, no history
  rewriting. Push once, at the end.
- Line width: these files wrap prose at ~76 characters. Every replacement block
  below is pre-wrapped; use it verbatim rather than re-wrapping by feel.

## Verified inventory of sites to change

Every line below was read this session at the cited anchor.

| Anchor | Current text (abridged) | Action |
|---|---|---|
| `config/instructions.md:94` | `` `kopipasta map <path>` `` | add `--json` |
| `config/agents/planner.md:30` | `` `kopipasta map <path>` (skill: `` | add `--json` |
| `config/agents/planner.md:43` | `` `kopipasta map` the `` | add `--json` |
| `config/agents/planner.md:45` | `` `kopipasta map --changed-since <base>` `` | add `--json` |
| `config/agents/conductor.md:42` | `` `kopipasta map <path>` `` | add `--json` |
| `config/agents/coder.md:35` | `` `kopipasta map <dir>` `` | add `--json` |
| `config/agents/opus-coder.md:41` | `` `kopipasta map` the affected subsystem `` | add `--json` |
| `config/agents/verifier.md:49` | `` `kopipasta map <path>` `` | add `--json` |
| `config/agents/verifier.md:104` | `` or `kopipasta map` the `` | add `--json` |
| `skills/codebase-map/SKILL.md:4` | description: `` `kopipasta map` `` | add `--json` |
| `skills/codebase-map/SKILL.md:20` | `` `kopipasta map` prints `` | add `--json` |
| `skills/codebase-map/SKILL.md:38,41,44` | `kopipasta map --help` / `usage: kopipasta map` | keep as-is |
| `skills/codebase-map/SKILL.md:65-71` | 7 example commands, only one has `--json` | all get `--json`; JSON-first rewrite |
| `skills/codebase-map/SKILL.md:74-100` | text format first, `--json` second | invert: JSON is the form, text is the opt-out |
| `skills/codebase-map/SKILL.md:109` | `kopipasta map --json > map.json` | already correct |
| `README.md:104` | `` check with `kopipasta map --help` `` | keep `--help`, append the `--json` default sentence |
| `install.ps1:101` | `Verify with: kopipasta map --help` | keep `--help`, append the default form |
| `install.sh` | no `kopipasta map` invocation at all (only install + key hints, `install.sh:77-93`) | no change |

<!-- CONTINUE -->
