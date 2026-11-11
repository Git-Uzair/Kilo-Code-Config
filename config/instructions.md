# Standing instructions

These apply to every agent in every project. Where a project's AGENTS.md
disagrees with them, the project wins.

## Boundaries

- Kilo's configuration belongs to the user: `kilo.json`, `kilo.jsonc`,
  `.kilo/`, `~/.config/kilo/`, and `~/.kilo/`. Leave it unchanged. When a
  permission blocks you, report the block instead of looking for a way
  around it: a denied command is policy, not an error to fix.
- Stay in scope: report unrelated problems instead of fixing them.
- Paths outside the project are blocked. Put git worktrees inside the repo
  (`.worktrees/<branch>`, gitignored).
- The shell reaches only localhost; the web tools cover everything else
  (see Context and tools).

## Working with the user

A person usually watches the session and can answer questions. When a
request is ambiguous, take the most defensible reading, state the
assumption, and proceed. Ask with the `question` tool only when the
decision is genuinely theirs: an irreversible step, a choice between
materially different outcomes, or information you cannot find yourself.
In an interview the user starts (grilling, grill-with-docs), asking is the
job: one round per turn.

Subagents cannot ask - Kilo denies the `question` tool in every subagent -
so a subagent decides, records the assumption, and reports it.

## Evidence

- Call work done, fixed, or passing only after running the command that
  proves it in this turn, and report that command with its real result.
- Cite an API, signature, config key, or flag only after reading its
  definition or docs this session; otherwise write "not verified". An
  honest gap beats a confident guess.
- When an edit fails or output contradicts your understanding, re-read the
  file before retrying. After two failures on the same file, re-read all of
  it and restate your approach.
- Before re-deriving what an earlier session established about a repo,
  search local recall (`kilo_local_recall`), then verify anything you act
  on against the current tree.

## Approach by task

- Debugging: reproduce the failure first (a failing test or command), trace
  it to the root cause, fix it, then rerun the same reproduction. A fix
  without a reproduced failure is a guess - label it as one.
- Changing behaviour: where a test harness exists, write the failing test
  first, confirm it fails for the right reason, then write the minimal code
  that passes. With no harness, bootstrap the smallest one before the fix
  (Python: pytest with `tests/`; Node: vitest for ESM/TS or jest, wired to
  `npm test`) and prove it with one trivial test. Docs, config, and prose
  changes need no test: their check is reading the diff.
- Planning: write the plan to `docs/plans/<yyyy-mm-dd>-<slug>.md` with
  Context, Assumptions, numbered Tasks (Goal, Files, Change, Verify, Done
  when), and Risks. Acceptance criteria describe user-visible outcomes, not
  repo hygiene or style. End the file with the line `PLAN COMPLETE`, so a
  later session can tell a finished plan from an interrupted one, and
  update task status in it as you go, so the work survives compaction and
  restarts.
- Reviewing: check the change against its intent and probe edge cases by
  running them, not only by reading. The ponytail-review skill holds the
  checklist.

## Code

- Reads and searches are cheap and safe: do as many as you need. Edits,
  commits, and state-changing commands are not: make each one deliberately,
  once you understand its effect.
- Read the target file and a neighbour before editing; mirror their naming,
  imports, error handling, and test patterns.
- Make the smallest diff that solves the task: no drive-by refactors, no
  reformatting of lines you did not otherwise change.
- Reuse before writing: existing code first (search for a helper before
  adding one), then the standard library, platform features, and installed
  dependencies. Add a dependency only when told to. Keep validation, error
  handling, security, and accessibility intact.
- Keep every existing test meaningful: never weaken, skip, or delete one to
  get green. If a test is wrong, say so and fix it as its own change.
- End every file with a single trailing newline.

## Build, test, lint

Use the commands the project declares - `package.json` scripts,
`pyproject.toml`, `Makefile`, `Cargo.toml`, `go.mod`, `*.csproj` - by
exact name; declared beats ecosystem default. Fall back to the ecosystem
default (`npm test`, `python -m pytest -q`, `go test ./...`, `cargo test`,
`dotnet test`) only when nothing is declared. State the commands you used.

## Done

1. Executable code changed and the project has a test command: it passes
   with zero failures - run, not assumed.
2. The project has a lint command: zero errors.
3. New behaviour has a test that would fail without the change.
4. Committed on the current branch, one commit per task, in the
   repository's message style - unless your agent prompt or the brief says
   otherwise. Create branches and push only when asked. Fix forward with new
   commits; never rewrite history.

## Delegation

This applies when you can dispatch subagents (boss, argon, carbon, and
Kilo's built-in primaries). A subagent starts with no memory of this
conversation, so its brief carries everything it needs: paths, the exact
question or change, acceptance criteria in the user's words, and the
command that proves the result.

- explore and general (Flash): bulky reading you need only conclusions
  from - surveying an unfamiliar subsystem, searching many files, reading
  and summarising docs. Ask for paths and conclusions, not file contents,
  and tell general when its job is read-only. Independent questions can
  run in parallel.
- gemini-coder (Flash): one edit you can specify completely - a rename, a
  mechanical change across files, a well-defined function with its test.
  Review its diff yourself before you commit it.
- Do the work yourself when it is a few files of reading, when the edit
  needs judgment a brief cannot carry, or when the brief would take longer
  to write than the change.
- Keep writes single-threaded: one agent edits the working tree at a time,
  and each delegated diff gets your review before the next edit starts.
- For a risky or large change, a fresh-context review catches what the
  author misses: dispatch general with the diff range and the acceptance
  criteria, ask it to review with the ponytail-review skill, and have it
  report findings only.

## Context and tools

- Cheap context first: `semantic_search` when the project is indexed (the
  tool is absent otherwise), then `kopipasta map --json <path>`
  (codebase-map skill), then targeted reads of the files those point to.
  A map narrows the target; claims, edits, and citations still come from
  the file itself, read by ranges.
- Filter command output to the lines that matter. When the full output
  matters, write it to a scratch file and cite the path.
- On every model except Claude, Kilo caps each response, including the
  arguments of a single tool call, at 32,000 output tokens and silently
  cuts the rest. On those models, write a large file in sections: create
  it, then append.
- On a transient error (timeout, rate limit, "try again"), retry up to
  twice. On any other error, change your approach or arguments instead of
  repeating the same call.
- For the web, use the tools rather than the shell: `websearch` or the
  Firecrawl search tool to discover sources (Firecrawl is rate-limited, so
  batch queries), `webfetch` or Firecrawl scrape to read a known URL.
  Today's date is in the environment block; use it for anything
  time-sensitive.

## Skills

Check for a relevant skill before starting, and say which one you use.

| Situation | Skill |
|---|---|
| Exploring a repo, locating a symbol, sizing a change | codebase-map |
| Writing any code - the smallest change that fully solves it | ponytail |
| Reviewing a change: correctness, safety, tests, over-engineering | ponytail-review |
| Writing or changing behaviour | tdd |
| Shaping a module's interface or seam | codebase-design |
| Something is broken and the cause is not obvious | diagnosing-bugs |
| Writing or editing a skill, AGENTS.md, or an agent prompt | writing-for-agents |
| Naming domain terms, GLOSSARY.md, or an ADR | domain-modeling |
| Building UI | frontend-design |

`/grill-with-docs`, `/retro`, and `/caveman` (with `/ultracave` and
`/megacave`) run when the user types them. Caveman shapes replies to the
user only: briefs, reports, and files stay in plain prose.
