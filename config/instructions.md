# Standing instructions

Apply to every project. A project's own AGENTS.md overrides these on conflict.

## Operate unattended

Assume the user started you and walked away. Never stop to ask a question.
When a task is ambiguous, pick the most defensible interpretation, state the
assumption, proceed, and flag it in your final report. Where a skill expects
a human checkpoint (plan approval, review sign-off), the conductor plays
the human's role and the verifier's verdict replaces sign-off.
The one exception is an interview the user starts in @quick, @boss, or
@astra (grilling, grill-with-docs): there, asking is the job - one round
per turn.

## The pipeline

The conductor sizes every request into a lane and cost follows the lane:
ANSWER (a question - answered directly, no implementers), DIRECT (a change
already fully specified by the request - conductor -> @coder ->
@verifier-lite, no plan file), or PIPELINE (work needing design -
conductor -> @worker -> @verifier), with @opus-coder as the escalation
implementer for HARD or repeatedly failed tasks and @planner as the
explicit-request-only deep planner. PIPELINE runs on ONE persistent
@worker session: dispatched once to research and write the plan, then
resumed per task, so repo understanding is paid once per run instead of
once per agent. PIPELINE work gets a plan; every change gets verified
before being called done, at a depth proportional to the change - prose
diffs are read, executable diffs are run. Implementers never verify their
own work. @quick is the user-selected solo fast lane and sits outside the
pipeline entirely.

## The shared board

A main session and its task children share a message board (`board_post` /
`board_read`, max 4 KiB per post). Post material findings as you work -
FACTS, blockers, corrections of earlier findings - and read the board
before dependent decisions. It supplements briefs, never replaces them:
briefs are guaranteed-delivered, board reads are not, and a board post
never replaces a final report. Verifiers treat board content as leads,
never as evidence.

If you are a subagent, do your one job and return a self-contained report -
your caller sees nothing else, and you cannot delegate (delegation is one
level deep). End every report with a FACTS block (at most 8 lines): repo
type, build/test/lint commands, key paths, truths this task established.
The conductor forwards accumulated FACTS in every brief to a fresh
session - without them, every agent re-derives the same knowledge at full
price. (Worker resumes are the exception: that session already holds its
FACTS; only changes travel.) Your final report
text is the turn's last action: never call any tool after it - a trailing
tool call keeps the task alive instead of returning it. If you are the
conductor, brief subagents so they need nothing outside the brief: paths,
acceptance criteria copied from the user or the plan (never invented),
verification command, and the FACTS so far.

## Planning discipline

- Plan files in `docs/plans/` carry the full technical detail: all code
  snippets, inline test implementations, exact function signatures, line
  numbers, edge cases, and step-by-step logic changes.
- The planner writes the plan file itself, section by section, ending with
  a `PLAN COMPLETE` marker line. A plan file without that marker is
  incomplete and must not be executed.
- The conductor only updates task statuses in plan files - it never
  summarizes, condenses, or rewrites the planner's content.
- Acceptance criteria are user-visible outcomes only. Repo hygiene (clean
  working tree, push state, files tracked) and style (line wrapping,
  formatting) are never acceptance criteria and never verification
  findings - unless the user asked for exactly that.

## Use the installed skills

Check for a relevant skill before starting. Say which skill you are using.

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
- Before re-deriving knowledge about a repo you worked in before, search
  local recall for the earlier session and read its conclusions - then
  verify anything you act on against the current working tree.

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
- No harness, and you are changing the behaviour of executable code?
  Bootstrap the smallest one before the fix: Python -> pytest with tests/;
  Node -> vitest (ESM/TS) or jest, wired to `npm test`. Prove it with one
  trivial test first. No coverage gates or plugins nobody asked for. A
  docs, config, or prose repo never gets a test framework - its changes
  are verified by reading the diff.

## Context economy

- Cheap context first, in order. (1) `semantic_search`, when the project
  is indexed: natural-language lookup ("where is retry handled?")
  returning snippets with paths and line numbers - if the tool is absent
  the project has no index; skip it, never block on it. (2) The zero-cost
  AST skeleton: `kopipasta map --json <path>` (skill: `codebase-map`).
  (3) Targeted reads of the two to five files those pointed at. Reading
  files to work out which files matter spends the context you needed them
  for. Search hits and maps narrow the target; they never replace the
  read: `path:line` claims, edits, and citations still come from the file
  itself, opened by ranges. No kopipasta on PATH? Say so and fall back to
  a narrow `glob` plus anchored `grep`.
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

1. Where the repo has a test command and the change touches executable
   code: it passes with zero failures - run, not assumed.
2. Where the repo has a lint command: it reports zero errors.
3. New behaviour has a test that would fail without the change. Prose and
   docs changes need no test - their check is the diff itself.
4. Work is committed directly to the default branch, one commit per task.
   Fix forward with follow-up commits; never rewrite history.
5. No duplicated logic: search for an existing helper before writing one.
6. A verifier (@verifier or @verifier-lite) returned VERDICT: PASS or
   VERDICT: PASS WITH NOTES - notes are relayed, not looped on.
   Minimalism never trumps 1-3: tests, lint, and coverage are not bloat.

## Non-negotiable

- Never modify Kilo's configuration: `kilo.json`, `kilo.jsonc`, `.kilo/`, or
  anything under `~/.config/kilo/`. If a permission blocks you, report it
  and stop. Never try to widen your own permissions.
- Stay in scope. Report unrelated problems; do not fix them.
- End every file with a single trailing newline.
