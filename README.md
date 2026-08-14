# Kilo Multi-Agent Pipeline

A production-hardened global configuration for the [Kilo Code CLI](https://kilo.ai)
that turns it into an unattended multi-agent engineering pipeline: point it at a
repo, give it a task, walk away. Built and battle-tested on Windows 11 against
Kilo CLI 7.4.22; the config itself is OS-agnostic.

No Kilo account or gateway required - you bring your own API keys.

## The pipeline

| Agent | Model | Role |
|---|---|---|
| **conductor** | gemini-3.7-flash *(Google)* | Default entry point. Routes work, drives the loop, never writes code. |
| **planner** | claude-opus-5 *(Bedrock)* | Researches the repo, writes an exhaustive plan file section-by-section, tags each task `EASY`/`HARD`. |
| **coder** | gemini-3.7-flash *(Google)* | First-line implementer: failing test first, minimal diff, commit per task. |
| **opus-coder** | claude-opus-5 *(Bedrock)* | Escalation implementer for `HARD` tasks and repeated failures. Gated - never the first resort. |
| **verifier** | claude-opus-5 *(Bedrock)* | Adversarial gate: runs the suite, probes edge cases empirically, audits scope/tests/secrets, emits `VERDICT: PASS/FAIL`. |

Opus runs through **Amazon Bedrock** on the EU inference profile
(`amazon-bedrock/eu.anthropic.claude-opus-5`), not the Anthropic API. Same
model, same list price, EU-pinned routing. The `anthropic` provider stays
enabled purely as a rollback: flip the three `model:` lines in
`config/agents/` back to `anthropic/claude-opus-5` and nothing else changes.

Flow: request → plan (with per-task acceptance criteria) → implement → verify →
loop on findings. Escalation to Opus fires on plan `HARD` tags or concrete
triggers (repeated failed cycles, repeated findings, gamed tests, conflicting
criteria), with an attempt ledger so no failed approach is ever retried.
Nothing is reported done without a literal verifier `PASS`.

Permissions are **allow/deny only - zero "ask" rules** - so sessions never
stall on prompts. A hardened deny-list blocks the destructive stuff outright
(deletion, force-push, non-localhost network, system mutation, publishing).

## Requirements

- Node.js 20+ and git on PATH
- Windows: PowerShell (7 recommended, 5.1 works). macOS/Linux: bash.
- An AWS account with **Bedrock model access granted for Claude Opus 5** in an
  EU region (Bedrock console -> Model access). This is an approval gate, not
  instant - nothing Opus works until it clears.
- API keys (set as env vars during install - never stored in this repo):
  - `GOOGLE_GENERATIVE_AI_API_KEY` - [Google AI Studio](https://aistudio.google.com)
  - `AWS_BEARER_TOKEN_BEDROCK` - a **long-term** Bedrock API key (AWS console). Short-term keys expire in <=12h and will kill an overnight run mid-flight.
  - `ANTHROPIC_API_KEY` *(optional)* - only needed if you roll the Opus agents back to the Anthropic provider. The pipeline runs fine without it.
  - `FIRECRAWL_API_KEY` *(optional)* - powers the agents' web search via MCP; without it, remove the `mcp.firecrawl` block from `config/kilo.jsonc`

No `AWS_REGION` needed - the region is pinned in `config/kilo.jsonc` under the
`amazon-bedrock` provider. Change it there if you move regions, and keep the
model IDs' geo prefix (`eu.`) in `config/agents/*.md` in step with it.

## Install

```powershell
# Windows
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config
./install.ps1            # pins @kilocode/cli@7.4.22 (tested); -Latest for newest
```

```bash
# macOS / Linux
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config && ./install.sh
```

The installer backs up any existing `~/.config/kilo` and `~/.kilo` before
touching them, installs the CLI, copies this config, clones the skill
repositories, installs the curated skill set, and prints the env-var commands
for your keys. Then verify:

```powershell
kilo agent list   # expect: conductor, planner, coder, opus-coder, verifier
```

## Usage

```powershell
# unattended one-shot run in any repo
kilo run --dir "C:\path\to\repo" --auto "implement X with tests"

# interactive TUI (conductor is the default agent)
kilo

# talk to a specialist directly
#   @planner  @coder  @verifier  @opus-coder   (in the TUI message box)

# escalate a stuck task by hand
#   "escalate this to @opus-coder"
```

Plans land in `docs/plans/<date>-<slug>.md` inside the target repo and double
as the run's progress ledger - task statuses, failed-cycle counts, and attempt
history are updated there as the run proceeds, so runs survive restarts.

Update skills later with: `~/.kilo/update-skills.ps1` (Windows) or re-run
`./install.sh` (Unix).

## Design notes (the scars behind the choices)

Each of these cost a broken run to learn; the config encodes the fix:

- **Subagents inherit the caller's permission ceiling.** Deny rules on the
  conductor cascade into every worker as unoverridable ceilings - so the
  conductor holds full permissions and its restraint lives in its prompt.
  Only `task` targets are hard-gated.
- **Delegation is one level deep, hardcoded.** Subagents cannot spawn
  subagents; every agent prompt accounts for it.
- **Never set `steps:` on any agent.** Kilo enforces the cap by appending a
  trailing assistant message, which both Anthropic (Claude 4.6+/5) and
  current Gemini reject at the API. Unset means the mechanism never fires.
- **32k output-token clamp per response** (hardcoded, inherited from
  upstream). The planner therefore writes its plan file incrementally via
  append-edits with a `PLAN COMPLETE` end marker, and the conductor refuses
  to execute a plan without the marker.
- **Subagent sessions snapshot their permissions at spawn.** Config fixes
  never reach a resumed `task_id` - the conductor is instructed to dispatch
  fresh tasks instead, especially after any denial.
- **Bedrock's region is pinned in `kilo.jsonc`, not `AWS_REGION`.** An env var
  only reaches processes started *after* it was set, so a TUI already running
  when the var is added inherits a stale environment: auth succeeds, region
  does not, and every Opus subagent dies with `AWS region setting is missing`.
  A region is not a secret, so it belongs in config where it is deterministic
  and survives a fresh clone with no extra setup step. Only the API key stays
  in the environment.
- **`web_search: true` survives the move to Bedrock - it is not provider-native.**
  The obvious assumption is that this flag maps to Anthropic's server-side
  `web_search` tool, which Bedrock does not expose, and that moving the Opus
  agents therefore costs them search. It does not. Kilo's `websearch` is its
  own service (results carry a `sku_search` usage line), so it is
  provider-agnostic. Verified on Bedrock: `websearch` is in the tool roster and
  returns real results. The Opus agents keep all three search paths -
  `websearch`, `webfetch` and the firecrawl MCP - and in practice reach for
  `webfetch`/firecrawl first for a known URL, per the standing instructions.
- **The `suggest` tool is denied for all subagents.** A trailing suggest call
  after a final report keeps the task spinning forever instead of returning.
- **Kilo's deprecated built-in `orchestrator` is disabled.** It sits one Tab
  away from the real conductor, hijacks runs with generic delegation, and
  ignores the verification gate.
- **The verifier can execute but never mutate**: git locked to read-only
  forms plus disposable detached worktrees (`.worktrees/`) for at-base and
  mutated-state testing.
- **Long-session hygiene**: Kilo 7.4.20 embeds Bun 1.3.14, which has a known
  Windows runtime defect
  ([bun#31941](https://github.com/oven-sh/bun/issues/31941), fixed in Bun
  1.4.0, not yet shipped in a Kilo build). Restart TUI sessions every few
  hours; the plan-file + commit-per-task design makes resuming free.
- **The grep tool hangs forever past 100 matches (Windows)**: kilo's `grep`
  caps results at an internal `MAX_SEARCH_LIMIT` of 100 (the `limit` param
  cannot exceed it), and the over-limit truncation path loses the search's
  completion on Windows - the call stays `"running"` forever with no child
  process, no error event, and no timeout, wedging the pipeline while the
  TUI keeps rendering. Deterministic and repo-independent: 90 matching lines
  returns, 150 hangs, in a fresh session on a scratch repo. Diagnose via the
  `part` table in `~/.local/share/kilo/kilo.db` (the stuck call keeps
  `"status":"running"`). The standing instructions therefore require narrow
  grep patterns and a bash pre-count when volume is uncertain; `glob` shares
  the same truncation path, so keep it specific too. Recovery: Esc to abort
  the hung turn, then dispatch a fresh task.

## What's in the box

```
config/kilo.jsonc          global config: models, providers, permissions, MCP, compaction
config/instructions.md     standing instructions injected into every agent
config/agents/*.md         the five pipeline agents (system prompt + permissions each)
scripts/update-skills.ps1  pulls skill repos, re-copies the curated set
install.ps1 / install.sh   one-shot setup
```

## Skills

Installed at setup by cloning upstream (not redistributed here):
[obra/superpowers](https://github.com/obra/superpowers) (MIT) - 9 skills
including test-driven-development, systematic-debugging,
verification-before-completion ·
[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (MIT) -
minimal-code posture + review ·
[anthropics/skills](https://github.com/anthropics/skills) (Apache-2.0) -
skill-creator, webapp-testing, frontend-design.

## License

MIT - see [LICENSE](LICENSE). The skill collections above remain under their
own licenses and are fetched from their upstream repositories at install time.
