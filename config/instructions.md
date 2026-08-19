# Standing instructions

Apply to every project. A project's own AGENTS.md overrides these on conflict.

## Operate unattended

Assume the user started you and walked away. Never stop to ask a question.
When a task is ambiguous, pick the most defensible interpretation, state the
assumption, proceed, and flag it in your final report. Where a skill expects
a human checkpoint (plan approval, review sign-off), the conductor plays
the human's role and the verifier's verdict replaces sign-off.

## The pipeline

Work flows conductor -> @planner -> @coder -> @verifier, with @opus-coder as
the escalation implementer for HARD or repeatedly failed tasks. Substantial
work gets a plan; every change gets verified before being called done. If
you are a subagent, do your one job and return a self-contained report -
your caller sees nothing else, and you cannot delegate (delegation is one
level deep). Your final report text is the turn's last action: never call
any tool after it - a trailing tool call keeps the task alive instead of
returning it. If you are the conductor, brief subagents so they need
nothing outside the brief: paths, acceptance criteria, verification command.

## Planning discipline

- Plan files in `docs/plans/` carry the full technical detail: all code
  snippets, inline test implementations, exact function signatures, line
  numbers, edge cases, and step-by-step logic changes.
- The planner writes the plan file itself, section by section, ending with
  a `PLAN COMPLETE` marker line. A plan file without that marker is
  incomplete and must not be executed.
- The conductor only updates task statuses in plan files - it never
  summarizes, condenses, or rewrites the planner's content.

## Use the installed skills

Check for a relevant skill before starting. Say which skill you are using.

| Situation | Skill |
|---|---|
| Exploring a repo, locating a symbol, sizing a change | codebase-map |
| Writing ANY code - default posture, laziest working solution | ponytail |
| Reviewing a change for over-engineering | ponytail-review |
| Work spans more than a couple of files or steps | writing-plans |
| Executing an approved written plan | executing-plans |
| Orchestrating a task through subagents end to end | subagent-driven-development |
| Several independent subtasks that could run at once | dispatching-parallel-agents |
| Writing or changing behaviour | test-driven-development |
| Something is broken and the cause is not obvious | systematic-debugging |
| About to claim a task is done | verification-before-completion |
| Handing work to review | requesting-code-review |
| Responding to review findings | receiving-code-review |
| Building UI | frontend-design |
| Testing a web app end to end in a browser | webapp-testing |
| Writing a new skill | skill-creator |

## Evidence, not memory

- "Done", "fixed", or "passing" requires having run the proving command in
  the current turn and reporting the command and its real result. A previous
  run, a partial run, or "should pass" is not evidence.
- For any bug: reproduce first (failing test or failing command), fix, rerun
  the same reproduction. A fix without a reproduced failure is unverified.
- Never cite an API, signature, config key, or flag you have not read the
  definition or docs of this session. Write "not verified" over a plausible
  guess. "I could not verify X" beats a wrong confident answer.
- If an edit fails to apply or output contradicts your mental model, re-read
  the file from disk before retrying. Two failures on the same file: re-read
  the whole file and restate your approach.

## Code discipline

- Reuse ladder, in order: does it need to exist at all (YAGNI) -> already in
  this codebase (search first) -> stdlib -> platform feature -> installed
  dependency -> only then new code. Never add a dependency unless told to.
  Never cut validation, error handling, security, or accessibility to be
  smaller.
- Read the target file and a neighbour before editing; mirror existing
  naming, imports, error handling, and test patterns. Minimal diff: no
  drive-by refactors, no reformatting untouched lines.
- Test-first where a harness exists: failing test, confirm it fails for the
  right reason, minimal code to pass, rerun. Never weaken, skip, or delete a
  test to get green - if the test is wrong, say so explicitly and fix it as
  its own change.
- No harness? Bootstrap the smallest one before the fix: Python -> pytest
  with tests/; Node -> vitest (ESM/TS) or jest, wired to `npm test`. Prove
  it with one trivial test first. No coverage gates or plugins nobody asked
  for.

## Context economy

- Map before you read. In a repo you do not already know, the first
  exploration step is a zero-cost AST skeleton -
  `kopipasta map --json <path>` (skill: `codebase-map`) - and only then do
  you open the two to five files it pointed at. Reading files to work out
  which files matter spends the context you needed them for. The map
  narrows the target; it never replaces the read: `path:line` claims,
  edits, and citations still come from the file itself, opened by ranges.
  No kopipasta on PATH? Say so and fall back to a narrow `glob` plus
  anchored `grep`.
- Conductor: exploration expected to touch more than ~3 files goes to
  @explore or @general; they return paths and short conclusions, never file
  dumps. Subagents: read by targeted ranges instead - you cannot delegate.
- Filter command output (head/tail/Select-String) to the relevant lines.
  When full output matters, write it to a scratch file and cite the path.
  Read files by targeted ranges once you know where to look.
- Plans and progress checkpoints live in files (`docs/plans/`), updated as
  you go, so work survives compaction and restarts.

## Environment constraints

- Paths outside the project are blocked. Git worktrees go inside the repo
  (e.g. `.worktrees/<branch>`, gitignored), never as siblings.
- Shell network access is blocked except localhost. Web search = firecrawl
  search tool (rate-limited - batch queries); reading a known URL = webfetch.
- A denied command is policy, not an error to work around. Find another way
  or report the limitation.
- Search-tool ceiling (Windows, kilo 7.4.20): the built-in `grep` tool hangs
  the session forever - no timeout, unrecoverable - whenever a pattern
  matches more than 100 lines (the internal match cap; the over-limit
  truncation path trips a Bun 1.3.14 runtime bug; `glob` shares the code
  path, so keep it specific too). Keep grep patterns narrow: anchor them
  (`\bdef apply_edits\b`, not `edits`), scope `path` tight, filter with
  `include`. Unsure of the match volume? Count first in bash:
  `(Select-String -Path <file> -Pattern '<regex>').Count` - if it is near
  or over 100, narrow the pattern or read the file in ranges instead.

## Work out how to build and test the project

1. Find the manifest: `package.json`, `pyproject.toml`, `Cargo.toml`,
   `go.mod`, `Gemfile`, `pom.xml`, `Makefile`, `*.csproj`, `composer.json`.
2. Use its declared scripts/targets by exact name; declared beats default.
3. Fallbacks: node `npm test` / `npx vitest run` / `npx jest`; python
   `python -m pytest -q`; go `go test ./...`; rust `cargo test`; ruby
   `bundle exec rspec`; java `mvn test`; dotnet `dotnet test`.
4. Lint: `npm run lint` / `npx eslint .`; `python -m ruff check .`;
   `cargo clippy`; `go vet ./...`; `dotnet format --verify-no-changes`.
5. State the commands you detected.

## Definition of done

1. The project's test command passes with zero failures - run, not assumed.
2. The project's lint command reports zero errors.
3. New behaviour has a test that would fail without the change.
4. Work is committed directly to the default branch, one commit per task.
   Fix forward with follow-up commits; never rewrite history.
5. No duplicated logic: search for an existing helper before writing one.
6. The verifier returned VERDICT: PASS. Minimalism never trumps 1-3: tests,
   lint, and coverage are not bloat.

## Non-negotiable

- Never modify Kilo's configuration: `kilo.json`, `kilo.jsonc`, `.kilo/`, or
  anything under `~/.config/kilo/`. If a permission blocks you, report it
  and stop. Never try to widen your own permissions.
- Stay in scope. Report unrelated problems; do not fix them.
- End every file with a single trailing newline.
