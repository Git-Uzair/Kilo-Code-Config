# Solo roster: retire the conductor pipeline

## Context

This repo's global Kilo config runs an eleven-agent pipeline. The
conductor (Flash) routes every request through worker, planner, coder,
opus-coder, verifier, and verifier-lite. Beside it sit three
user-summoned heavyweights (boss, astra, argon) and the quick fast lane.
On 2026-11-04 the user asked to keep only boss, argon, and quick, rename
coder to gemini-coder, remove the pipeline and verifier agents, keep
every skill, and apply current research on CLI agents and prompting.

Facts established in the research session (2026-11-04, kilo 7.8.18):

- npm `latest` is 7.8.18, which is installed. The installers pin 7.8.1
  and the README says 7.7.1.
- A `default_agent` that names a missing agent throws `default agent
  "<name>" not found` (`packages/opencode/src/agent/agent.ts:482`). Only
  an unset key falls back to `code`. Deleting conductor without changing
  `default_agent` breaks every session start.
- Since 7.8.2 Kilo requests the full output limit for Claude models
  (`kilocode/session/llm.ts`, `outputTokens`). Every other provider
  keeps the 32,000-token cap (`provider/transform.ts:22`). boss's "32k
  trap" section is obsolete; the Gemini agents still need it.
- The grep tool no longer hangs past 100 matches. A fresh `kilo run` on
  a 300-match scratch file printed `Found 100 matches (more matches
  available)` and exited.
- Since 7.8.13 a custom agent's own `edit` rules and broad `bash` denies
  no longer cap the subagents it starts (`kilocode/tool/task.ts`,
  `inherited()`). Kilo itself denies `question`, `suggest`, and `task`
  in every subagent (`KiloTask.permissions`).
- Kilo reads only `name` and `description` from skill frontmatter. The
  7.8.18 binary contains no `disable-model-invocation`.
- Google: Gemini 4 and 3.6+ ignore `temperature`, `top_p`, and `top_k`,
  return deprecation warning headers, and will return 400 in a future
  release (ai.google.dev, prompting-strategies). Three agents set 0.1.
- Anthropic (Opus 5.5 prompting guide): start effort at `medium` and
  keep `xhigh`/`max` for measured gains; soften aggressive emphasis.
  Opus verifies its own work and delegates readily, so a prompt should
  say when subagents are warranted.
- Cognition (2026-04-22): multi-agent setups work when writes stay
  single-threaded and the extra agents contribute reads or review.
- All 15 vendored skills match their pins byte for byte. Every upstream
  has moved, no license changed, and a closure dry run at upstream HEAD
  finds no open references.

## Assumptions

The user approved the proposal with "proceed with the plan". Its open
choices take the recommended option:

1. `default_agent` becomes `quick`: the cheap default, with Tab to boss
   or argon.
2. Primary agents ask only when a decision is genuinely the user's.
   Subagents stay autonomous.
3. The `openai` and `amazon-bedrock` providers go, because no remaining
   agent uses them.
4. boss drops from `max` to `xhigh` effort.
5. The installers mirror `config/agents/` the way they already mirror
   `skills/`: after the existing backup, they remove agent files this
   repo no longer ships. Otherwise the retired agents stay live after a
   reinstall.
6. gemini-coder never commits. The calling agent reviews and commits.

## Tasks

### Task 1: Pin kilo 7.8.18

- Goal: the installers install the version this restructure was
  verified on.
- Difficulty: EASY
- Files: `install.ps1`, `install.sh`
- Test first: none (installer constant and comment)
- Change: `$pin` / `PIN` 7.8.1 -> 7.8.18. Rewrite the pin-history
  comment to record what 7.8.18 re-verified and what it did not.
- Verify: read the diff; `bash -n install.sh`.
- Done when: both installers pin 7.8.18.

### Task 2: Retire the pipeline agents

- Goal: only boss, argon, quick, and coder ship, and a session starts in
  quick.
- Difficulty: MEDIUM
- Files: `config/agents/{conductor,worker,planner,opus-coder,verifier,
  verifier-lite,astra}.md` (delete), `config/kilo.jsonc`, `install.ps1`,
  `install.sh`
- Test first: none (config; the scratch load below is the check)
- Change:
  - `git rm` the seven agent files.
  - `kilo.jsonc`: set `default_agent` to `quick` and correct its comment
    (an invalid value throws; it does not fall back). Update the model
    roster comment. Drop the `openai` and `amazon-bedrock` provider
    blocks and their `enabled_providers` entries. Refresh comments that
    name the conductor, worker, astra, or Bedrock.
  - Installers: mirror `~/.config/kilo/agents` (remove `*.md` files not
    shipped in `config/agents/`), drop the Bedrock and OpenAI key hints,
    update the banner and the expected-roster line.
- Verify:
  - Copy `config/` into a scratch `XDG_CONFIG_HOME`, then run `kilo
    debug paths`, `kilo config check`, `kilo agent list`, and `kilo debug
    config`.
  - Run the installer's mirror block, extracted verbatim, against
    scratch directories.
  - `bash -n install.sh`.
- Done when:
  - The scratch config resolves `default_agent` to `quick` without
    errors, and no retired agent is listed.
  - The mirror removes a stale agent file and keeps the shipped ones.

### Task 3: Re-vendor skills at upstream HEAD

- Goal: the vendored skills carry their upstream fixes.
- Difficulty: EASY
- Files: `skills/vendor.psd1`, vendored `skills/*` folders,
  `skills/codebase-map/SKILL.md`
- Test first: none (the sync script's closure check is the gate)
- Change:
  - Run `./scripts/sync-skills.ps1 -Latest` and paste the printed
    commits into `vendor.psd1`.
  - Refresh comments the update made stale: ponytail no longer says
    "pair with Caveman", and the `tdd` acknowledgement names the
    verifiers.
  - `codebase-map` line 226: replace "(verifier)" with a reviewer role.
- Verify:
  - The closure check passes.
  - A blob-level comparison of every vendored file against upstream at
    the new pins shows no differences.
  - Review `git diff --stat -- skills`.
- Done when: the pins are upstream HEAD and the vendored bytes equal
  upstream.

### Task 4: Rename coder to gemini-coder

- Goal: boss and argon can hand fully specified edits to a cheap Flash
  implementer.
- Difficulty: MEDIUM
- Files: `config/agents/coder.md` -> `config/agents/gemini-coder.md`,
  `config/agents/boss.md`, `config/agents/argon.md` (task permission
  only)
- Test first: none (agent prompt)
- Change:
  - `git mv`, then rewrite the description, frontmatter, and prompt:
    - Frontmatter: drop `temperature` and the inert
      `interactive_terminal` deny; deny the git commands that commit,
      discard work, or move HEAD.
    - Prompt: a brief is the contract; numbered steps; error handling;
      the 32k note; a fixed report format; never commit.
  - Add `gemini-coder: allow` under `permission.task` in boss and argon.
- Verify: in the scratch config, `kilo agent list` shows gemini-coder
  as a subagent, `kilo debug agent gemini-coder` shows its model and
  permissions, and `kilo debug agent boss` shows the task allow.
- Done when: boss and argon can dispatch gemini-coder, and no `coder`
  agent remains.

### Task 5: Rewrite the boss, argon, and quick prompts

- Goal: each prompt follows its vendor's current guidance and none
  depends on the pipeline.
- Difficulty: MEDIUM
- Files: `config/agents/boss.md`, `config/agents/argon.md`,
  `config/agents/quick.md`
- Test first: none (agent prompts)
- Change:
  - boss: variant `xhigh`; calm prose that explains its reasons;
    delegation rules (when explore, general, and gemini-coder are
    warranted and when not; one writer at a time; review and commit
    after a delegated edit); no pipeline or conductor references; drop
    the 32k section.
  - argon: drop `temperature`; constraints first; error-handling and
    risk rules; date anchoring for web search; keep the 32k section;
    the same delegation rules.
  - quick: drop `temperature`; it is now the default agent; hand off
    to boss or argon instead of the conductor; a 32k one-liner.
- Verify: the scratch `kilo config check` and `kilo agent list`; read
  the diffs.
- Done when: no agent sets `temperature`, and no file under
  `config/agents/` names a retired agent.

### Task 6: Rewrite the standing instructions

- Goal: a short, calm core that every model can follow.
- Difficulty: MEDIUM
- Files: `config/instructions.md`
- Test first: none (prose)
- Change:
  - Remove: the pipeline lanes, the board and FACTS protocol, the
    verifier done-gate, and the grep ceiling.
  - Add: the attended stance.
  - Keep: the boundaries, evidence rules, code discipline, build/test
    detection, done criteria (commit-by-default, overridable per agent),
    context economy, environment, and skills table. The
    `ponytail-review` row now describes a full review.
- Verify: read the diff; grep `config/` for retired agent names.
- Done when: no retired agent, lane, or verdict gate remains in
  `config/`.

### Task 7: Update the README and AGENTS.md for the solo roster

- Goal: the docs describe what ships.
- Difficulty: MEDIUM
- Files: `README.md`, `AGENTS.md`
- Test first: none (prose)
- Change:
  - README: new title and intro; a table of the four agents plus the
    built-in explore and general; requirements without Bedrock or
    OpenAI; pin 7.8.18; usage examples. In the design notes, mark what
    7.8.18 re-verified and drop notes about the retired agents. Skills
    section: ponytail-review is now a full review; the interview gate
    covers quick, boss, and argon.
  - AGENTS.md: drop the verifier-lite and worker lines; add the
    installer-mirroring fact and the scratch-config check.
- Verify: read the diffs; `git grep` for the retired agent names
  outside `docs/plans/`.
- Done when: no stale roster, lane, or pin remains outside historical
  plans.

## Risks

- Dropping `openai` and `amazon-bedrock` removes those models from the
  picker. To revert, restore the provider blocks and the
  `enabled_providers` entries.
- boss at `xhigh` may be weaker than `max` on the hardest tasks. To
  revert, change one line, or pass `kilo run --variant max` for a single
  run.
- Agent mirroring deletes agent files a user added by hand to
  `~/.config/kilo/agents` (the timestamped backup keeps them).
- ponytail v5 changes the reply style (replies end with what was
  skipped or unchecked) and the code-comment marker (`shortcut:`).
- ponytail-review now triggers on "review this" and runs a full review
  ending in a `Verdict:` line.
- On 7.8.18, compaction can start before the configured threshold. The
  fix ships only in the 7.8.20 release candidate.
- The prompt changes are judged against vendor guidance only; nothing
  here benchmarks them.

PLAN COMPLETE
