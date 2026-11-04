# Kilo Code CLI config

A global configuration for the [Kilo Code CLI](https://kilo.ai) with:

- three agents you talk to;
- one cheap implementer they delegate to;
- a vendored skill set;
- an allow/deny permission envelope.

You bring your own API keys; no Kilo account or gateway is required.
Pinned to Kilo CLI 7.8.18 and last verified on Windows 10 22H2
(2026-11-04). The config itself is OS-agnostic.

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

- Node.js 22+ (the Firecrawl MCP server requires it) and git on PATH.
- Windows: PowerShell 7 (recommended). Windows PowerShell 5.1 also
  works, but its default execution policy on Windows clients
  (Restricted) blocks scripts, so start the installer there with
  `powershell -ExecutionPolicy Bypass -File .\install.ps1`.
  macOS/Linux: bash.
- Google Chrome, for the browser tools: the Playwright MCP server drives
  it. The installer warns when it is missing.
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

Set the keys before or after installing (the installer prints these
commands too):

```powershell
# Windows (user scope)
[Environment]::SetEnvironmentVariable("GOOGLE_GENERATIVE_AI_API_KEY","<your-google-key>","User")
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY","<anthropic-key-for-boss>","User")
[Environment]::SetEnvironmentVariable("FIRECRAWL_API_KEY","<optional-firecrawl-key>","User")
```

```bash
# macOS / Linux (add to your shell profile)
export GOOGLE_GENERATIVE_AI_API_KEY="<your-google-key>"
export ANTHROPIC_API_KEY="<anthropic-key-for-boss>"
export FIRECRAWL_API_KEY="<optional-firecrawl-key>"
```

Then open a new terminal before starting `kilo`: a process that is
already running keeps the environment it started with.

## Install

```powershell
# Windows
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config
./install.ps1            # pinned versions; -Latest for newest
```

```bash
# macOS / Linux
git clone https://github.com/Git-Uzair/Kilo-Code-Config.git kilo-config
cd kilo-config && ./install.sh   # --latest for newest
```

The installer:

1. checks for Node.js 22+ and backs up any existing `~/.config/kilo`
   and `~/.kilo`;
2. installs, globally via npm and at pinned versions, the Kilo CLI
   (`@kilocode/cli@7.8.18`) and the two MCP servers the config launches
   (`firecrawl-mcp@3.36.1`, `@playwright/mcp@0.0.84`), then checks for
   Google Chrome;
3. copies this config, mirroring `config/agents/` into
   `~/.config/kilo/agents` and `skills/` into `~/.kilo/skills`, and
   removing any agent or skill this repo no longer ships (the backup
   keeps them);
4. installs `kopipasta` (via `uv` or `pip`, best effort);
5. if `herdr` is on PATH, installs its config and Kilo plugin (see
   [Herdr](#herdr-one-place-for-many-sessions));
6. prints the environment-variable commands for your keys;
7. lists the installed agents and the status of both MCP servers.

Then verify, in a new terminal:

```powershell
kilo agent list   # expect quick, boss, argon, gemini-coder (plus Kilo's built-ins)
kilo mcp list     # expect firecrawl and playwright: connected
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

# boss at max effort for one run (its default is xhigh);
# in the TUI, ctrl+t cycles the current model's variant (its effort level)
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

## Herdr: one place for many sessions

[Herdr TUI](https://herdr.dev/tui/docs/) (Apache-2.0; v0.9.5 when this
was written) is optional: a terminal workspace manager for coding agents.

- Its server owns the panes, so closing the window leaves every agent
  running.
- A sidebar shows which agents are working, which are blocked waiting for
  you, and which have finished.
- After a reboot it restores the layout and reopens each Kilo
  conversation with `kilo --session <id>`. Kilo reopens a conversation in
  the agent it last used, so a boss pane normally returns as boss.

**Install.**

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
```

On macOS/Linux use `curl -fsSL https://herdr.dev/install.sh | sh`. Then
re-run `./install.ps1` (or `./install.sh`) in a new terminal. With herdr
on PATH, the installer:

1. copies `config/herdr/config.toml` to `%APPDATA%\herdr\config.toml`
   (`~/.config/herdr/config.toml` on macOS/Linux), backing up any
   existing file;
2. runs `herdr integration install kilo`, which adds
   `~/.config/kilo/plugin/herdr-agent-state.js`;
3. prints `herdr integration status`.

The plugin reports Kilo's state to herdr and does nothing outside a
herdr pane. On Windows the herdr binary is unsigned, so SmartScreen may
warn on first run.

**Keys.** The prefix is ctrl+q, not herdr's default ctrl+b: in the Kilo
TUI ctrl+b sends running subagents to the background.

| Key | Action |
|---|---|
| `ctrl+q c` | new tab |
| `ctrl+q v` / `ctrl+q -` | split right / down |
| `ctrl+q h`/`j`/`k`/`l` | move between panes |
| `ctrl+q w` | workspaces |
| `ctrl+q q` | detach, leaving everything running (`herdr` reattaches) |
| `ctrl+q ?` | help |

**Working with it.**

- One workspace per repo and one tab per task. In a pane, run `kilo`
  (quick) or `kilo --agent boss` / `kilo --agent argon`.
- Start a new conversation in a new tab, not with `/new` inside a running
  Kilo pane: herdr tracks the first session a pane reports and resumes
  that one.
- Keep one writer per checkout, and never open the same session in two
  panes. On Kilo 7.8.18 a second process can delete a reply the first is
  still writing, and a scheduled wakeup can fire twice. Both are fixed in
  7.8.23, which has not yet reached Kilo's `latest` channel.
- Parallel work in one repo goes into a worktree. From the repo, run
  `herdr worktree create --cwd . --branch <name>`. The checkout opens as
  its own workspace under `~/.herdr/worktrees/<repo>/<branch-slug>`.
  Remove it with `herdr worktree remove --workspace <id>` (ids come from
  `herdr workspace list`); this deletes the checkout and keeps the
  branch.
- Kilo sessions in the same checkout share one Playwright browser
  profile, and only one of them can have the browser open at a time; the
  second gets "Browser is already in use". A worktree is a different
  directory, so it gets its own profile.
- Panes are started by the herdr server, so an API key set after the
  server started may not reach new panes. Run `herdr server stop`, then
  `herdr`: the layout returns and Kilo conversations resume.
- Every pane running boss is a separate Opus session, and they bill in
  parallel.

**Not used here.**

- herdr's agent skill: its distinctive feature is agents starting other
  agents in panes, which brings back parallel writers.
- The Herdr desktop app: a separate product whose agents are not shared
  with the TUI.

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
- **The MCP servers are installed, not fetched per session.** The
  installers put `firecrawl-mcp` and `@playwright/mcp` on PATH at pinned
  versions. `kilo.jsonc` launches `firecrawl-mcp` and
  `playwright-mcp --browser chrome` by name, where it used to run
  `npx -y ...` (with Playwright at `@latest`) as each session started.
  Verified on 7.8.18: `kilo mcp list` shows both connected when the
  binaries are on PATH and both failed when they are not.
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
config/herdr/config.toml   Herdr TUI config (optional; installed when herdr is on PATH)
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
