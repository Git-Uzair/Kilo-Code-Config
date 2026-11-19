# Model-agnostic Max roster and Gemini 4 Hydrogen @ high

## Context

The repository currently ships three model-pinned frontier agents (`boss` on
`anthropic/claude-opus-5-5`, `argon` on `google/gemini-4-argon`, `carbon` on
`google/gemini-4-carbon`), a solo `quick` default on `google/gemini-3.8-flash`,
and a `gemini-coder` subagent on `google/gemini-3.8-flash`, with built-in
utility/subagent roles (`explore`, `general`, `title`, `summary`, `compaction`)
also pinned to `google/gemini-3.8-flash` and `enabled_providers` locked to
`["google", "anthropic"]`.

The user requested:

1. A model-agnostic setup across all configuration, standing instructions, and
   agent prompts so switching models in Kilo never conflicts with prompt text
   or provider allowlists.
2. Retiring `boss`, `argon`, and `carbon` in favor of a single end-to-end
   agent `max`, set as `default_agent`, switchable to any SOTA frontier model.
3. Moving `general`, `explore`, `quick`, and the other small/utility agents
   currently on `google/gemini-3.8-flash` to `google/gemini-4-hydrogen` at
   `variant: high`.
4. Incorporating current (November 2026) agent-harness and prompting best
   practices and checking all skills for needed updates.

Facts established in this session (2026-11-19, `@kilocode/cli@7.8.27`):

- `@kilocode/cli@7.8.27` is both npm `latest` and installed locally. It
  includes the 7.8.20 compaction-threshold fix and the 7.8.23 multi-pane and
  scheduled-wakeup fixes noted as pending in `README.md`.
- In `Kilo-Org/kilocode` at `v7.8.27` (`packages/tui/src/context/local.tsx`),
  `apply(a.name, model, !a.model)` persists a user's `/models` (`ctrl+x m`)
  selection to `~/.local/share/kilo/storage/model.json` **only when the agent
  omits `model:`** in its config/frontmatter. Setting `model:` on `max` makes
  TUI model switches ephemeral (`persist = false`). Omitting both `model:` and
  `variant:` on `max` lets `/models` persist the chosen model and `ctrl+t`
  persist the reasoning effort per `provider/model`, while falling back to
  top-level `model` in `kilo.jsonc` before any pick is saved.
- In `v7.8.27` (`packages/opencode/src/provider/provider.ts` and `kilo models
  anthropic --verbose`), Anthropic models carry `api.url: ""` and use
  `@ai-sdk/anthropic`'s native `/v1` default; the 7.4.23 `baseURL` workaround
  is no longer required, and omitting unconfigured `provider.<id>.options`
  entries prevents unauthenticated providers from appearing in `/models`.
- Replacing `"enabled_providers": ["google", "anthropic"]` with
  `"disabled_providers": ["kilo"]` hides the unauthenticated Kilo Gateway while
  allowing any BYOK, cloud, or local provider (`google`, `anthropic`, `openai`,
  `openrouter`, `xai`, `amazon-bedrock`, or custom `provider` entries) to load
  automatically from credentials or `kilo auth`.
- `google/gemini-4-hydrogen` (GA 2026-11-12) has a unified 1,048,576-token
  input+thinking+output window, 65,536 synchronous output tokens, fixed
  sampling parameters (custom `temperature` ignored), and variants `low`,
  `medium`, `high`, and `xhigh`. `kilo config check` and `kilo debug agent`
  accept `"model": "google/gemini-4-hydrogen"` with `"variant": "high"` on
  built-in agents as well as `subagent_model` / `subagent_variant`.
- `OUTPUT_TOKEN_MAX = 32_000` (`packages/opencode/src/provider/transform.ts`)
  still caps single-step output on non-Claude providers; phrasing the
  sectioned-write rule once in `config/instructions.md` without naming any
  provider keeps every agent safe and model-agnostic.
- Current harness guidance (Anthropic Opus 5.5 & Claude Code best practices,
  Google Gemini 4 Carbon/Hydrogen & Harness Engineering guides, OpenAI
  GPT-6.2 Astra guide, Cognition single-threaded multi-agent findings):
  drop meta-thinking filler ("think carefully"), scale ceremony to task size,
  define an observable finish line, verify via commands and `git diff` rather
  than self-reading prose, keep writes single-threaded, and treat external
  content (web, tool output, repo comments, peer notes) as untrusted data.
- All 14 vendored skills (`SKILL.md` and 7 companion markdown files) match
  upstream `HEAD` byte for byte across `mattpocock/skills`,
  `JuliusBrussee/caveman`, `DietrichGebert/ponytail`, and `anthropics/skills`;
  `kopipasta` on PyPI remains `0.70.0`, and `skills/codebase-map/SKILL.md` is
  already model-agnostic. No skill files need changes.

## Assumptions

1. The new default agent is named `max` (`config/agents/max.md`,
   `"default_agent": "max"`), matching Kilo's lowercase CLI/agent convention.
2. `gemini-coder` is renamed back to `coder` (`config/agents/coder.md`) on
   `google/gemini-4-hydrogen` at `variant: high`, removing the last
   model-specific agent name from the roster and prompts.
3. Top-level `"model"` in `config/kilo.jsonc` is `"google/gemini-4-hydrogen"`,
   giving `max` a working out-of-the-box fallback with only
   `GOOGLE_GENERATIVE_AI_API_KEY` until the user selects a frontier model in
   `/models` (which then persists ahead of `fallbackModel`).

## Tasks

### Task 1: Pin `@kilocode/cli` to `7.8.27` — `[done]`

- Goal: Installers pin the verified `7.8.27` CLI release.
- Files: `install.ps1`, `install.sh`
- Change: Update `$pin` / `PIN` from `7.8.18` to `7.8.27` and refresh the
  pin-history comment with the `7.8.27` verification notes.
- Verify: Read `git diff -- install.ps1 install.sh`; parse-check `install.ps1`
  in PowerShell.
- Done when: Both installers pin `@kilocode/cli@7.8.27` without syntax errors.

### Task 2: Make `config/instructions.md` model-agnostic and apply 2026 harness rules — `[done]`

- Goal: Every agent inherits lean, model-agnostic standing instructions with
  current harness guardrails.
- Files: `config/instructions.md`
- Change:
  - Remove all model and retired-agent names (`boss`, `argon`, `carbon`,
    `gemini-coder`, `Flash`, `Claude`).
  - Add the untrusted-data boundary for external content (web, tool output,
    pasted logs, repo comments, board notes).
  - Tighten verification and completion rules (observable check + `git diff` +
    re-reading the prompt before reporting; honest statement of unchecked
    gaps).
  - Update `Delegation` to name `max` and `coder`, preserving single-threaded
    writes and fresh-context `ponytail-review`.
  - Replace the provider-branched 32,000-token note with a single
    model-agnostic sectioned-write rule.
- Verify: Read `git diff -- config/instructions.md`; grep `config/instructions.md`
  for model/vendor and retired-agent names.
- Done when: `config/instructions.md` contains zero model, vendor, or retired
  agent names and covers every shared harness rule once.

### Task 3: Ship `max` (default), `quick`, and `coder` with Hydrogen @ high defaults and open BYOK providers — `[done]`

- Goal: Sessions start in `max`, `/models` switches persist across restarts for
  any provider's frontier model, and `quick`, `coder`, `explore`, `general`,
  `title`, `summary`, and `compaction` run on `google/gemini-4-hydrogen` at
  `high` thinking.
- Files: `config/agents/{boss,argon,carbon,gemini-coder}.md` (delete),
  `config/agents/{max,quick,coder}.md`, `config/kilo.jsonc`, `install.ps1`,
  `install.sh`, `README.md`, `AGENTS.md`
- Change:
  - Delete `boss.md`, `argon.md`, `carbon.md`, and `gemini-coder.md`.
  - Create `config/agents/max.md` (`mode: all`, no `model:` or `variant:` so
    TUI `/models` and `ctrl+t` selections persist; end-to-end engineering,
    debugging, design, planning, research, and review instructions).
  - Update `config/agents/quick.md` and create `config/agents/coder.md` on
    `google/gemini-4-hydrogen` at `variant: high` with model-agnostic
    descriptions and prompts.
  - Update `config/kilo.jsonc`: `"default_agent": "max"`, `"model"`,
    `"small_model"`, and `"subagent_model"` on `"google/gemini-4-hydrogen"`,
    `"subagent_variant": "high"`, `"disabled_providers": ["kilo"]` replacing
    `"enabled_providers"`, simplified `"provider"` block, and `"variant":
    "high"` with `"google/gemini-4-hydrogen"` on `explore`, `general`,
    `title`, `summary`, and `compaction`.
  - Update `install.ps1`, `install.sh`, `README.md`, and `AGENTS.md` in the
    same commit per `AGENTS.md` agent-rename invariant.
- Verify:
  - Scratch `XDG_CONFIG_HOME` check: `kilo config check`, `kilo agent list`,
    and `kilo debug agent` for `max`, `quick`, `coder`, `explore`, `general`,
    `title`, `summary`, and `compaction`.
  - Grep `config/` for any remaining `3.8-flash`, `boss`, `argon`, `carbon`,
    `gemini-coder`, or model names inside prompt prose.
  - Fresh-context `@general` review (`ponytail-review`) of the full diff range.
- Done when: `kilo config check` reports zero warnings, `max` is the default
  agent with no hardcoded `model`, all small/subagent roles resolve to
  `google/gemini-4-hydrogen` at `variant: high`, and docs/installers match.

## Risks

- `google/gemini-4-hydrogen` shares its 1,048,576-token window across input,
  thinking, and output, and bills `$1.50` / `$7.50` per 1M tokens on the paid
  tier (2x `gemini-3.8-flash` per token through 2026-12-31, partly offset by
  fewer turns and `$0.075` implicit caching). `compaction` at 40% keeps context
  headroom open for thinking and output.
- Replacing `enabled_providers` with `disabled_providers: ["kilo"]` exposes any
  provider whose credentials exist in the user's shell environment (for
  example AWS credentials surfacing `amazon-bedrock` in `/models`). A user who
  wants to hide an auto-detected provider can add its ID to
  `disabled_providers`.
- Re-running `install.ps1` overwrites `~/.config/kilo/kilo.jsonc` (after making
  a timestamped `.bak-<stamp>` backup), so any custom local provider block
  added directly to `~/.config/kilo/kilo.jsonc` must be re-applied or kept in a
  separate config layer (`KILO_CONFIG`).

PLAN COMPLETE
