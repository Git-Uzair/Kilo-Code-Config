# Context reuse and a Flash-first pipeline

Date: 2026-09-15. Target: this config repo (`config/`), then installed via
`install.ps1`. No changes have been made yet; this plan is the deliverable.

## Context

- The machine runs `@kilocode/cli` **7.7.1** (checked live: `kilo --version`
  -> 7.7.1; npm latest is 7.7.1, published 2026-09-15). The installer still
  pins **7.5.16**, and every agent prompt encodes 7.4.x-era constraints.
- The complaint: PIPELINE lane re-derives repo understanding at every hop.
  Conductor explores, then Opus planner re-explores, then Flash coder
  re-reads, then Opus verifier re-reads. Wall-clock cost is dominated by
  three redundant repo-understanding passes, two of them at Opus speed.
  The user routes around it with @boss/@astra, paying more, precisely
  because a single session keeps its context.
- Root cause, named: the planner writes an exhaustive plan file BECAUSE
  context dies between planner and coder. The detail is compensation for
  amnesia. Remove the amnesia and the Opus-grade plan detail is no longer
  load-bearing for most work.
- Platform facts verified this session (docs + release notes + the live
  7.7.1 runtime):
  - **Task resume keeps context**: `task` with a prior `task_id` continues
    the same child session "with its previous messages and tool outputs"
    (live 7.7.1 task-tool schema; kilo.ai/docs/automate/tools, Task tool).
  - **Kilo Swarm shared board**: `board_post`/`board_read` shared by a main
    session and all its task descendants, incl. nested subagents. ON by
    default since 7.7.0 (`experimental.shared_agent_board`; release
    v7.7.0 #14134; kilo.ai/docs/getting-started/settings#kilo-swarm).
    Messages max 4 KiB; history readable by all participants.
  - **Codebase indexing + `semantic_search`**: opt-in `indexing` config key;
    Gemini embeddings (`gemini-embedding-001`) + embedded LanceDB (no
    server); Tree-sitter chunking; incremental re-index on file changes;
    persists across sessions and agents
    (kilo.ai/docs/customize/context/codebase-indexing).
  - **Local recall**: agents can search titles + high-signal chat content of
    past local sessions (incl. child sessions) in the workspace and read a
    chosen transcript (kilo.ai/docs/code-with-ai/agents/session-history).
  - **Per-task model override**: `experimental.task_model_selection` lets a
    dispatching agent request a different model/provider/reasoning effort
    for an individual subagent task (7.5.8 release notes #13557; off by
    default; docs say overrides are honored only when explicitly
    requested).
  - **`interactive_terminal` was removed** in 7.6.0 (release #13793). All
    `interactive_terminal: deny` lines in this config are dead but
    harmless.
  - Permission denials can now carry user feedback (7.7.0 #14051);
    `kilo run --session <id>` resumes a session non-interactively;
    wakeup scheduling exists (7.7.0 #14094).
- Cost/time model of the fix: one Flash worker session reads the repo ONCE
  and keeps it across plan + all implementation tasks (provider prompt
  caching makes the reused prefix cheaper per turn, not more expensive).
  Opus leaves the default path entirely: the Opus planner role is retired
  from routine PIPELINE work; Opus remains for escalation (@opus-coder),
  deep verification of HARD work (@verifier), and explicit user requests.
  Expected effect: fewer total tokens (no triple re-derivation), most
  remaining tokens at Flash prices, and wall-clock dominated by one
  exploration instead of three.
- Verification independence is preserved deliberately: the worker never
  verifies its own work; verifiers stay separate fresh sessions. (A forked
  worker session as verifier was considered and rejected: it would inherit
  the implementer's assumptions - the exact bias the verifier exists to
  catch.)
- This is a prose/config repo: no tests, no lint. Verification is diff
  reading plus the named live smoke commands. Style: ~76-column wrap for
  new prose; never an acceptance criterion.

## Assumptions

- "Rely more on Gemini 3.8 Flash" means: Flash does planning-lite,
  implementation, and routine verification; Opus stays only where its
  judgment is the product (escalation, HARD-task verification). It does
  not mean deleting the Opus agents.
- The machine intentionally runs 7.7.1 (newer than the 7.5.16 pin), so the
  config should be brought up to the running version rather than the
  version rolled back. The pin moves to 7.7.1.
- The 7.4.x scars (steps-cap wrap-up bug, grep>100 hang, anthropic /v1
  baseURL, turn-control wedges) stay encoded until someone re-tests them
  on 7.7.1; each is harmless when fixed upstream. Re-testing is a
  follow-up, not part of this plan's critical path (Task 1 smoke-checks
  only what the new architecture depends on).
- Plan files in `docs/plans/` remain the durable ledger for PIPELINE runs
  (restart safety, audit), but their required detail drops: the worker
  that wrote the plan also executes it, so the plan records decisions and
  acceptance criteria, not every code snippet a stranger would need.
- API keys never land in config files. If the `indexing` block cannot
  resolve its key from an env var, indexing ships disabled with setup
  documented instead (Task 2 verifies empirically).
- Board messages supplement briefs; the conductor's FACTS-in-brief
  mechanism stays (a brief is guaranteed-delivered; a board read is not).

## Tasks

### Task 1 - Move the pin to 7.7.1 and record the feature baseline

- **Goal**: installer, README, and version-caveat notes match the CLI that
  is actually running, so the new features this plan depends on are
  guaranteed present on a fresh install.
- **Difficulty**: EASY
- **Verify**: lite
- **Files**: `install.ps1` (the `$pin` line and its comment), `README.md`
  (version references, requirements), `AGENTS.md` (if it names the pin).
- **Test first**: none (prose/config). Pre-change evidence commands:
  `kilo --version` (expect 7.7.1), `npm view @kilocode/cli version`.
- **Change**: set `$pin = '7.7.1'`; update the pin-history comment (7.5.16
  -> 7.7.1 on 2026-09-15, reason: Kilo Swarm board, task-resume
  architecture, codebase indexing, wakeups all require >=7.6/7.7; note
  that 7.4.x-era workarounds remain un-re-verified and are kept). In
  README, update the "pinned to" sentence and add one line to the design
  notes: `interactive_terminal` was removed upstream in 7.6.0, so its
  deny lines are inert but retained for older installs.
- **Done when**: `install.ps1` contains `$pin = '7.7.1'`; README states the
  new pin and its date; no other behavioural text contradicts 7.7.1.

### Task 2 - Enable codebase indexing (Gemini embeddings + LanceDB)

- **Goal**: give every agent persistent, cross-session repo understanding
  via the `semantic_search` tool, so "understand the repo" is paid once
  per project, not once per subagent.
- **Difficulty**: EASY (config), with one empirical gate.
- **Verify**: isolated (run the checks below immediately; this is the one
  task whose failure changes later prompt wording).
- **Files**: `config/kilo.jsonc` (new top-level `indexing` block).
- **Test first**: none. Empirical gate instead, in a scratch repo:
  1. Add the block with the key sourced from the environment, NOT inline:
     `"indexing": { "enabled": true, "provider": "gemini",
     "model": "gemini-embedding-001", "vectorStore": "lancedb",
     "gemini": { "apiKey": "{env:GOOGLE_GENERATIVE_AI_API_KEY}" } }`
  2. Copy to `~/.config/kilo/kilo.jsonc`, open a session in a small code
     repo, run `/indexing` in the TUI: status must reach In Progress /
     Complete, and `semantic_search` must appear in the tool roster and
     return results for a natural-language query.
  3. UNVERIFIED and decisive: whether `{env:...}` substitution works
     inside the `indexing` block (docs only show inline keys). If it does
     not resolve, do NOT inline the key - ship the block with
     `"enabled": false`, document one-command enablement in README, and
     drop the semantic_search-first wording from Task 6 to "when an index
     exists".
- **Change**: the block above, with a comment mirroring the repo's style:
  why Gemini embeddings (existing key, cheap), why LanceDB (embedded, no
  server, Windows-supported), and the privacy note (snippets only).
  Indexing is per-project opt-in at runtime; the config only makes it
  available - projects enable it globally or per-project per the docs.
- **Done when**: scratch-repo check above passes with the env-substituted
  key (or the documented fallback ships); `config/kilo.jsonc` still
  parses (`kilo agent list` runs clean after copy).

### Task 3 - Add the @worker agent (Flash, plan-then-execute in one session)

- **Goal**: one persistent Flash subagent that researches, writes the plan
  file, and then - resumed by task_id - implements task after task with
  its research context intact. This merges planner+coder for PIPELINE
  work and is the core fix.
- **Difficulty**: HARD (prose, but it encodes the new protocol; a wrong
  word here costs runs, and two reasonable authors would write it
  differently).
- **Verify**: full
- **Files**: `config/agents/worker.md` (new).
- **Test first**: none (prose). Acceptance is the live smoke in Task 4.
- **Change**: create the agent with:
  - Frontmatter: `mode: subagent`, `model: google/gemini-3.8-flash`,
    `temperature: 0.1`, permissions denying `suggest`, `question`,
    `plan_enter`, `plan_exit` (same subagent wedge class as coder;
    `interactive_terminal` deny retained-as-inert or omitted - match
    Task 1's README note either way).
  - Prompt, phase-structured:
    - **Phase P (first dispatch)**: research with `semantic_search` (when
      available) + `kopipasta map --json` + targeted reads; write the plan
      to `docs/plans/<yyyy-mm-dd>-<slug>.md` - Context / Assumptions /
      numbered Tasks (Goal, Difficulty EASY|HARD, Verify full|lite|
      isolated, Files, Done when) / Risks, ending `PLAN COMPLETE` -
      lighter than the old planner format: decisions and acceptance
      criteria, not code-snippet dictation, because the author executes
      it. 32k clamp: append sections incrementally. Post a FACTS summary
      to the board (`board_post` INFO to the conductor). Return path +
      task list + `PLAN COMPLETE` receipt.
    - **Phase E (each resume)**: the resume message names one task (or an
      explicit batch); re-read that plan section; failing test first
      where a harness exists; minimal diff; full suite + lint; commit per
      task; never push unless told; report files/commit/test tails +
      FACTS block. Never verify your own work; never widen scope; if the
      brief and repo conflict, follow the repo and record the deviation.
    - **Degraded mode**: if dispatched WITHOUT a prior plan phase (fresh
      session, e.g. after a denial forced a fresh dispatch), say so, read
      the plan file named in the brief, and continue as a coder would.
  - Escalation stays outside: worker never self-escalates; the conductor
    owns the ladder.
- **Done when**: `kilo agent list` (after install-copy) shows `worker
  (subagent)`; the prompt contains the P/E phase contract, the plan-file
  format with `PLAN COMPLETE`, the degraded mode, and the 32k append
  rule; @verifier PASS on the diff against this task's text.

### Task 4 - Rewire the conductor's PIPELINE lane around worker resume

- **Goal**: PIPELINE becomes: dispatch @worker once (plan phase), check the
  `PLAN COMPLETE` marker, then RESUME the same task_id per plan task
  (execute phase), verifying per the existing rules. No @planner, no
  @coder in this lane; repo understanding is paid once.
- **Difficulty**: HARD (protocol prose; interacts with every existing
  conductor rule).
- **Verify**: full, plus the live smoke below.
- **Files**: `config/agents/conductor.md`.
- **Test first**: none (prose). Live smoke AFTER install-copy: in a scratch
  code repo, run one small PIPELINE-shaped request unattended
  (`kilo run --dir <scratch> --auto "..."`); then confirm single-worker
  reuse: `kilo db "SELECT s.id, count(m.id) FROM session s JOIN message m
  ON m.session_id = s.id WHERE s.parent_id IS NOT NULL GROUP BY s.id"`
  (or inspect `kilo session list`) - expect ONE worker child session with
  multiple user turns (plan + execute resumes), not N fresh children.
- **Change** (surgical edits, not a rewrite of unrelated sections):
  - `permission.task`: add `worker: allow` (keep the rest; planner stays
    allowed for explicit user requests).
  - **PIPELINE: plan** section: dispatch @worker with the user's request +
    FACTS; on receipt, the conductor still tail-checks `PLAN COMPLETE`
    (unchanged rule). If the marker is missing, resume the SAME task_id
    once to finish the plan (context is the point); only fall back to a
    fresh worker dispatch if the resume errors.
  - **PIPELINE: build** section: per plan task, RESUME the worker task_id
    with a short brief: task number, acceptance criteria copied from the
    plan, verifier findings if any. Keep: one task at a time; update plan
    statuses. Drop: re-sending the full FACTS block on every resume (the
    session already holds it - that is the feature); still send facts
    that changed since the last turn.
  - **Resume-safety rule** (replaces the blanket resume warning): resume
    the worker task_id freely during a healthy run; dispatch a FRESH
    worker (degraded mode, pointed at the plan file) after any permission
    denial in the child, any config change mid-run, or a resume error -
    the permission-snapshot scar (README design notes) still applies on
    those paths.
  - **Escalation ladder**: unchanged in shape. EASY-task fix cycles go
    back to the worker via resume with findings verbatim; the triggers
    (second failed cycle, gamed test, conflicting criteria) and plan-tag
    HARD still escalate to @opus-coder as a fresh dispatch carrying plan
    section + ledger + diffs. Three-cycle budget, frozen re-verify
    surface, attempt ledger: all unchanged.
  - **DIRECT lane**: unchanged (@coder + @verifier-lite). Note in the lane
    text: DIRECT stays cheaper for fully-specified changes because it
    skips the plan phase entirely.
  - **Verification routing**: unchanged (@verifier-lite for DIRECT and
    `Verify: lite` tasks; @verifier once after the final PIPELINE task or
    per `Verify: isolated`). A worker implementation still never counts
    as verified without a verifier verdict.
- **Done when**: the smoke run produces a plan file with `PLAN COMPLETE`,
  one resumed worker session, a verifier verdict line, and a final report;
  conductor.md diff shows no changes to ANSWER/DIRECT semantics,
  acceptance-criteria rules, or verdict handling beyond the resume
  protocol; @verifier PASS.

### Task 5 - Demote @planner to explicit-request-only

- **Goal**: stop routing routine PIPELINE work to the Opus planner; keep it
  as an opt-in deep-planning specialist, and as the format reference for
  plans handed to the pipeline by @boss/@astra.
- **Difficulty**: EASY
- **Verify**: lite
- **Files**: `config/agents/planner.md` (description + one prompt line),
  `config/agents/conductor.md` (already covered by Task 4's lane text; add
  the explicit trigger: "dispatch @planner instead of the worker's plan
  phase only when the user names @planner or asks for a deep/Opus plan"),
  `README.md` (pipeline table row).
- **Test first**: none.
- **Change**: planner.md description gains "Explicit-request-only since
  2026-09-15: routine PIPELINE planning moved to @worker (Flash,
  plan-then-execute)". Its RECOMMEND DIRECT LANE backstop and format stay
  (worker's plan format is the lighter variant; planner remains the
  exhaustive one for plans that WILL be executed by a context-free
  stranger).
- **Done when**: no conductor path reaches @planner without the user
  naming it; README table matches.

### Task 6 - Teach the fleet the new context sources (instructions + prompts)

- **Goal**: agents prefer cheap persistent context - semantic_search, the
  Swarm board, local recall, AGENTS.md - before re-deriving anything.
- **Difficulty**: EASY (mechanical prompt additions, several files)
- **Verify**: lite
- **Files**: `config/instructions.md` (Context economy section),
  `config/agents/{worker,coder,verifier,verifier-lite,boss,astra,quick}.md`
  (one short block each), `skills/codebase-map/SKILL.md` (one paragraph).
- **Test first**: none.
- **Change**:
  - instructions.md exploration ladder becomes: (1) `semantic_search` when
    the project is indexed - natural-language lookup, snippets with
    path:line; (2) `kopipasta map --json` skeleton; (3) targeted reads.
    Claims and edits still come from opened files, never from search
    snippets alone.
  - instructions.md gains a short "Shared board" paragraph: subagents post
    material findings (FACTS, blockers, corrected findings) to the board
    and read it before dependent decisions; briefs remain authoritative;
    board posts never replace the final report. Mirror wording from the
    runtime's own guidance so prompts and platform agree.
  - instructions.md gains one line under Evidence: before re-exploring a
    repo you have seen in a previous session, search local recall first.
  - Agent files get one-to-three-line pointers to the same (worker's is
    written in Task 3; verifiers get "board findings are leads, not
    evidence - verify independently").
  - codebase-map SKILL.md notes: when `semantic_search` is available it
    comes first for "where is the code that does X"; kopipasta map remains
    the free structural skeleton and the fallback when no index exists.
- **Done when**: diff shows the ladder, board, and recall text present and
  consistent across files; no agent is told the board replaces briefs.

### Task 7 - Compaction model to Flash (optional, decide at execution)

- **Goal**: worker sessions now live long by design; compaction at the 40%
  threshold should be fast and cheap rather than maximal-quality.
- **Difficulty**: EASY
- **Verify**: lite
- **Files**: `config/kilo.jsonc` (`agent.compaction.model`).
- **Test first**: none.
- **Change**: `"compaction": { "model": "google/gemini-3.8-flash" }`,
  comment noting the trade (speed/cost over summary quality) and that
  cb8c23c chose Astra deliberately - revert is one line. Skip this task
  entirely if the user prefers Astra-quality compaction; it is
  independent of everything else.
- **Done when**: config parses; comment records the trade and rollback.

### Task 8 - Experiment: per-task model override for escalation (isolated)

- **Goal**: establish whether `experimental.task_model_selection` lets the
  conductor resume/dispatch the worker with an Opus override for HARD
  tasks, which would keep even escalations inside the same context.
- **Difficulty**: HARD (unverified feature; touches escalation semantics)
- **Verify**: isolated - purely empirical, in a scratch repo, before any
  prompt depends on it.
- **Files**: `config/kilo.jsonc` (`experimental.task_model_selection:
  true`) - only if the experiment succeeds and the user wants it;
  otherwise nothing ships.
- **Test first**: n/a (this IS the test).
- **Change**: enable the flag on the live config copy only; verify (a) the
  task tool exposes model/effort parameters to the conductor, (b) an
  override on a RESUMED task_id either works or cleanly refuses, (c)
  defaults stay untouched when no override is requested. Record findings
  in this plan file's ledger. Ship config + conductor wording only on
  success; @opus-coder remains the escalation path regardless (fresh
  Opus context is sometimes the point of escalation - a stuck worker's
  context can be the disease, not the cure).
- **Done when**: findings recorded with real transcript evidence; config
  change shipped or explicitly rejected.

### Task 9 - Documentation sweep

- **Goal**: README and design notes describe the pipeline that actually
  runs.
- **Difficulty**: EASY
- **Verify**: lite
- **Files**: `README.md` (pipeline table: add worker, annotate planner;
  flow paragraph; design notes: task-resume architecture, Swarm board,
  indexing, recall, 7.7.1 baseline, interactive_terminal removal),
  `AGENTS.md` (one line: worker exists; plans may be lighter when the
  worker executes its own plan).
- **Test first**: none.
- **Change**: as above, wrapped ~76 cols, no absolute local paths.
- **Done when**: a fresh reader of README predicts the observed smoke-run
  behaviour (Task 4) without reading agent files.

## Risks

- **Resume behaviour regressions**: the whole design leans on task_id
  resume preserving context. Task 4's smoke run proves it before anything
  is reported done; if resume misbehaves on 7.7.1, fall back to the
  degraded worker mode (fresh dispatch + plan file) - which is today's
  architecture, so nothing gets worse.
- **Flash planning quality**: some tasks genuinely need Opus-grade design.
  Mitigations: the plan-tag HARD -> @opus-coder ladder is unchanged; the
  user can name @planner for a deep plan; verifiers are unchanged. Watch
  the first weeks' FAIL rates; if worker plans FAIL disproportionately,
  reintroduce Opus planning for PIPELINE tasks the conductor sizes as
  large (>5 tasks) - one lane-text line.
- **Long worker sessions hit compaction mid-task**: compaction at 40% with
  prune is already configured; the worker's plan file and commits are the
  restart ledger, and the degraded mode covers a trashed session. Task 7
  makes compaction fast if chosen.
- **Indexing key handling**: if `{env:}` does not substitute inside
  `indexing`, ship it disabled (Task 2 gate). Never inline the key.
- **Editing `config/kilo.jsonc` may hit the basename deny** (`edit:
  {"kilo.jsonc": "deny"}` in the live config). History shows this repo's
  copy has been edited by agents before (commits 8447865, cb8c23c), so it
  is expected to work; if a denial fires anyway, 7.7.0 denial-feedback
  lets the user approve or apply the block by hand - the diff is small.
- **Swarm board noise**: prompts must keep board use material-only (Task 6
  wording); the board never gates verdicts, so worst case is wasted
  tokens, capped at 4 KiB per post.
- **Rollback**: every task is a one-commit prose/config change on `main`;
  reverting any single commit restores the previous behaviour. The old
  pipeline (planner+coder) remains intact underneath - the conductor
  lane text is the only switch.

PLAN COMPLETE

