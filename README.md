# Kilo Code CLI config

A global configuration for the [Kilo Code CLI](https://kilo.ai) with:

- three agents you talk to;
- one cheap implementer they delegate to;
- a vendored skill set;
- an allow/deny permission envelope.

You bring your own API keys; no Kilo account or gateway is required.
Built on Windows 11 and pinned to Kilo CLI 7.8.18 (2026-11-04). The
config itself is OS-agnostic.

## Agents

| Agent | Model | Role |
|---|---|---|
| **quick** *(default)* | gemini-3.8-flash *(Google)* | Small, well-defined tasks done end to end while you watch. Works alone, writes no plan files, commits only when asked. |
| **boss** | claude-opus-5-5 @ xhigh *(Anthropic)* | The hardest work: design, debugging with an unclear cause, planning, review of risky changes. Delegates errands to Flash. |
| **argon** | gemini-4-argon @ high *(Google)* | The same role as boss, on Google's frontier model. |
| **gemini-coder** | gemini-3.8-flash *(Google)* | Subagent for boss and argon: implements one fully specified change test-first, runs tests and lint, reports its diff, and never commits. |
| explore, general | gemini-3.8-flash *(Google)* | Kilo's built-in subagents, pinned to Flash, for bulky reading and research. |

**How work flows.**

- Every session starts in quick. Tab cycles to boss and argon (and to
  Kilo's built-in primaries).
- boss and argon do the reasoning and the delicate edits themselves.
- They delegate two kinds of work: bulky reading goes to explore or
  general, and edits they can specify completely go to gemini-coder.
- Writes stay single-threaded: one agent edits the tree at a time, and
  the delegating agent reviews every delegated diff before committing it.
- For a risky change they can ask general for a fresh-context review
  using the ponytail-review skill.

**Why this shape.** Until 2026-11-04 this repo ran an eleven-agent
pipeline: a Flash conductor routed every request through planners,
coders, and verifiers. It was replaced on evidence.

- Cognition (2026-04-22, cognition.com/blog/multi-agents-working) found
  that multi-agent systems "work best today when writes stay
  single-threaded and the additional agents contribute intelligence
  rather than actions".
- The same post found that when a weaker model decides when to escalate,
  "the quality ceiling was set by the primary".

So the strong models now sit in front, and the cheap ones run errands.

**Permissions are allow/deny only - zero "ask" rules - so sessions never
stall on approval prompts.** A deny-list blocks destructive commands
outright: deletion, force-push, non-localhost network, system mutation,
and publishing.

## Requirements

- Node.js 20+ and git on PATH.
- Windows: PowerShell (7 recommended, 5.1 works). macOS/Linux: bash.
- API keys, set as user-scope environment variables (never stored in this
  repo):
  - `GOOGLE_GENERATIVE_AI_API_KEY`, from
    [Google AI Studio](https://aistudio.google.com). It runs quick, argon,
    gemini-coder, the built-in subagents, compaction, and the
    codebase-indexing embeddings.
  - `ANTHROPIC_API_KEY` - powers boss. Everything else runs without it.
  - `FIRECRAWL_API_KEY` *(optional)* - Firecrawl MCP for web search and
    scraping. Without it, remove the `mcp.firecrawl` block from
    `config/kilo.jsonc`.
  - `GEMINI_API_KEY` *(optional)* - only for `kopipasta ask`.

## Install

```powershell
# Windows
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config
./install.ps1            # pins @kilocode/cli@7.8.18; -Latest for newest
```

```bash
# macOS / Linux
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config && ./install.sh   # --latest for newest
```

The installer:

1. backs up any existing `~/.config/kilo` and `~/.kilo`;
2. installs the CLI and copies this config;
3. mirrors `config/agents/` into `~/.config/kilo/agents` and `skills/`
   into `~/.kilo/skills`, removing any agent or skill this repo no longer
   ships (the backup keeps them);
4. installs `kopipasta` (via `uv` or `pip`, best effort);
5. prints the environment-variable commands for your keys.

Then verify:

```powershell
kilo agent list   # expect quick, boss, argon, gemini-coder (plus Kilo's built-ins)
```

## Usage

```powershell
# interactive TUI, starting in quick; Tab cycles to boss and argon
kilo

# start in a heavyweight
kilo --agent boss
kilo --agent argon

# one headless run (--auto approves anything not explicitly denied)
kilo run --dir "C:\path\to\repo" --agent boss --auto "implement X with tests"

# boss at max effort for one run (its default is xhigh)
kilo run --agent boss --variant max "..."

# sharpen a design by interview first (quick, boss, and argon only)
#   /grill-with-docs   in quick (cheap) or boss / argon (deep)

# after a session: what should change in the harness itself?
#   /retro

# terse replies until "stop caveman"
#   /caveman           (/ultracave or /megacave compress harder)
```

When boss or argon plan, the plan goes to
`docs/plans/<date>-<slug>.md` in the target repo. It ends with
`PLAN COMPLETE`, and task statuses are updated in the file as work
proceeds, so a run survives restarts and compaction.

Skills update with the repo: `git pull`, then re-run the installer.

`kopipasta` is optional but assumed by the `codebase-map` skill; without
it, agents fall back to plain reads. It needs Python 3.10+. Install it by
hand with `uv tool install kopipasta` (or `pip install kopipasta`) and
check it with `kopipasta map --help`. The standard invocation is
`kopipasta map --json`.

## Design notes

Each of these cost a broken run to learn, and the config encodes the fix.
Findings re-verified on 7.8.18 (2026-11-04) say so; the rest date from
kilo 7.4.x and are kept because each is harmless on a version that fixed
the underlying bug.

- **`default_agent` must name a real, visible primary agent.**
  Re-verified on 7.8.18. A missing agent aborts every run with
  `default agent "<name>" not found`; Kilo does not fall back. Only an
  unset key falls back to the built-in `code`. Rename or remove the
  default agent and `default_agent` must change in the same commit.
- **Subagents run under their own rules, not their caller's.** Changed in
  7.8.13 (changelog) and read in `kilocode/tool/task.ts` at the v7.8.18
  tag.
  - A custom agent's `edit` rules and broad `bash` denies no longer cap
    the subagents it starts. Each subagent gets the global rules plus its
    own frontmatter, appended last so its rules win.
  - Kilo itself denies `question`, `suggest`, and `task` in every
    subagent: subagents cannot ask the user or spawn subagents of their
    own.
  - That is why gemini-coder carries its own git denies (commit, push,
    reset, checkout, restore, stash, and other state-changing commands).
    It shares the caller's working tree, and those commands could destroy
    the caller's uncommitted work.
- **The 32k output cap now binds only non-Claude models.** Since 7.8.2,
  Claude on first-party routes requests its full output limit; every
  other model keeps the 32,000-token cap per response, and the overflow
  is silently truncated. The Gemini agents therefore write large files in
  sections. boss does not need to.
- **No temperature on Gemini agents.** Google's prompting guide (read
  2026-11-04) says Gemini 4 and 3.6+ ignore custom `temperature`,
  `top_p`, and `top_k`, return deprecation warning headers, and will
  return HTTP 400 in a future release. The old `temperature: 0.1` lines
  are gone.
- **The grep hang is fixed.** Re-verified on 7.8.18.
  - Old behaviour (kilo 7.4.20, Windows): a grep with more than 100
    matches stayed `"running"` forever and wedged the session.
  - On 7.8.18 the same test against a 300-match file returns
    `Found 100 matches (more matches available)` and exits normally.
  - The narrow-pattern workaround has been removed from the
    instructions.
  - The Bun runtime behind it is fixed too: 7.5.0 builds with Bun 1.4
    and 7.8.7 with Bun 1.4.2. The old advice to restart long TUI sessions
    every few hours no longer applies.
- **Never set `steps:` on any agent.** Kilo enforces the cap by appending
  a trailing assistant message, which Anthropic (Claude 4.6+/5) and
  current Gemini reject at the API. Left unset, the mechanism never fires.
  Not re-verified on 7.8.18.
- **The turn-control tools `suggest`, `plan_enter`, and `plan_exit` are
  denied on every custom agent.**
  - Plans are files in `docs/plans/`, not Kilo's plan mode.
  - A trailing turn-control call once left sessions spinning forever:
    `suggest` after a final report (2026-08-08), and `plan_exit` parking
    a session on a follow-up question no one could answer (2026-08-12,
    2026-08-21).
- **Interview skills are gated by permission.** Kilo reads only `name`
  and `description` from skill frontmatter; the 7.8.18 binary has no
  `disable-model-invocation`.
  - `kilo.jsonc` denies `grilling` and `grill-with-docs` globally.
  - quick, boss, and argon re-allow them, because only an attended
    session has a user to interview.
- **Kilo's deprecated built-in `orchestrator` is disabled.** It once
  hijacked a run with generic delegation.
- **Kilo 7.4.23 dropped `/v1` from the Anthropic API URL.**
  - Requests went to `api.anthropic.com/messages`, which does not exist,
    so boss failed with a bare `Not Found` and no error body naming the
    cause.
  - `kilo.db`'s `AI_APICallError` records carry the bad URL, and the same
    request replayed at `/v1/messages` returns 200.
  - The fix is the pinned `baseURL: "https://api.anthropic.com/v1"` (the
    SDK appends `/messages`). It is harmless on versions that build the
    URL correctly. Not re-verified on 7.8.18.
- **`web_search: true` is not provider-native.** `websearch` routes to
  Parallel through Kilo's built-in mcp-parallel transport, independent of
  the model provider. It needs neither a Kilo account nor a search API
  key of yours.
- **Codebase indexing ships configured but disabled.** The `indexing`
  block in `config/kilo.jsonc` uses gemini-embedding-001 and embedded
  LanceDB, with the key via `{env:GOOGLE_GENERATIVE_AI_API_KEY}`.
  - Turn it on by flipping `enabled` to true (indexes every workspace),
    or per project with `/indexing` in the TUI.
  - The `semantic_search` tool then appears in every agent's roster.
    Agents use it first when it is present and skip it when it is not.
- **Compaction runs at 40% of the context window, on Flash.** The 7.8.20
  release candidate fixes auto-compaction starting well before the
  configured threshold; on the 7.8.18 pin it can fire early.
- **The installers mirror agents and skills.** Deleting a file in
  `config/agents/` or `skills/` removes it from the live config on the
  next install, so retired agents cannot linger in the picker.

## What's in the box

```
config/kilo.jsonc          global config: models, providers, permissions, MCP, compaction
config/instructions.md     standing instructions injected into every agent
config/agents/*.md         the four agents (system prompt + permissions each)
skills/                    every skill the harness loads (vendored + local codebase-map)
skills/vendor.psd1         upstream repo, pinned commit, license files per vendored skill
scripts/sync-skills.ps1    re-vendors skills from vendor.psd1, checks dependency closure
install.ps1 / install.sh   one-shot setup
docs/plans/                plans for changes to this repo
```

## Skills

Every skill the harness loads ships in `skills/`. The installers mirror
that folder into `~/.kilo/skills` and remove anything else there (the
pre-install backup keeps it). To keep a skill of your own, add it to
`skills/`.

Third-party skills are vendored byte-for-byte at the commits pinned in
`skills/vendor.psd1` (last refreshed to upstream HEAD on 2026-11-04).
Each folder carries its upstream license.

- [mattpocock/skills](https://github.com/mattpocock/skills) (MIT):
  `tdd`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`,
  `grilling`, `grill-with-docs`, `retro`, `writing-for-agents`.
- [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
  (Apache-2.0, NOTICE included): `caveman`, `ultracave`, `megacave`. Only
  the skill folders are vendored, not the Caveman CLI, proxy, or gateway.
- [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
  (MIT): `ponytail` (the smallest change that fully solves the task) and
  `ponytail-review`. ponytail-review is a full quality review:
  correctness, safety, load, tests, speed, and leanness, with numbered
  findings and a verdict.
- [anthropics/skills](https://github.com/anthropics/skills)
  (Apache-2.0): `frontend-design`.

There is one local skill (MIT, same as the config): `codebase-map`. It
maps a repository's symbols with
[kopipasta](https://github.com/mkorpela/kopipasta) before any file is
read, so exploration costs one command instead of a fan-out of reads.

Every skill that a shipped skill depends on ships too, and
`scripts/sync-skills.ps1` re-checks that on every sync.

To refresh the vendored skills (maintainers):

1. Run `./scripts/sync-skills.ps1 -Latest`.
2. Review `git diff -- skills`.
3. Paste the printed commits into `skills/vendor.psd1`.
4. Commit.

## License

MIT - see [LICENSE](LICENSE). Vendored skills under `skills/` keep their
upstream licenses (MIT or Apache-2.0), and each vendored folder carries
its license file(s).
