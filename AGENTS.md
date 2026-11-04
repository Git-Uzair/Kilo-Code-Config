# AGENTS.md

Facts every agent needs when working in THIS repository. Read once, trust,
do not re-derive.

- This repo is prose and configuration: the Kilo CLI global config
  (`config/kilo.jsonc`), standing instructions (`config/instructions.md`),
  agent prompts (`config/agents/*.md`), installers, and every skill the
  harness loads (`skills/`). Nothing here executes at runtime except the
  installers and the maintainer-run `scripts/sync-skills.ps1`.
- `skills/` holds vendored third-party skills (byte copies at the
  commits pinned in `skills/vendor.psd1`) plus the local `codebase-map`.
  Never hand-edit a vendored folder - the next sync overwrites it; adapt
  the harness around a skill in `config/` instead.
- There is NO test suite, NO build, and NO lint command - and none should
  ever be bootstrapped. Changes here are verified by reading the diff
  against the request. Changes under `config/` can also be load-checked
  without touching the live config: copy `config/kilo.jsonc` and
  `config/instructions.md` into `<tmp>/kilo/` and `config/agents/*.md`
  into `<tmp>/kilo/agents/`, set `XDG_CONFIG_HOME=<tmp>`, then run
  `kilo config check`, `kilo agent list`, and `kilo debug agent <name>`
  (resolved model, variant, and permission rules). A live `kilo run`
  there still reads the installed instructions file: the `~/` in the
  `instructions` entry expands to the real home directory, not
  `XDG_CONFIG_HOME` (kilo `session/instruction.ts`), so point the scratch
  copy's entry at its own `instructions.md` before testing prompt
  behaviour.
- Prose wraps at roughly 76 columns. That is a style preference for new
  text you write - never an acceptance criterion, never a verification
  finding, and never a reason to re-wrap lines you did not otherwise
  touch.
- `KiloCode.md` in the repo root is downloaded vendor documentation,
  gitignored on purpose. Never commit it, never audit it.
- `docs/plans/` may contain absolute local paths; sanitize new plan files
  before committing them.
- This repo is the source of truth that the installers copy FROM. The
  installed live config lives at `~/.config/kilo/` - editing that
  directly is always wrong here; edit `config/` and re-run `install.ps1`
  (or copy the changed file over manually when asked). The installers
  mirror `config/agents/` and `skills/`: a file deleted here disappears
  from the live config on the next install.
- `~/.config/kilo/plugin/` belongs to herdr, not to this repo:
  `herdr integration install kilo` writes `herdr-agent-state.js` there.
  The installers must never mirror or clean that folder, or a reinstall
  silently breaks herdr's Kilo state reporting and session resume.
  `config/herdr/config.toml` is herdr's own config; the installers copy
  it only when `herdr` is on PATH.
- An agent's name is its filename in `config/agents/`. Renaming or
  removing one means updating, in the same change: `default_agent` in
  `config/kilo.jsonc` (a missing default agent aborts every run), the
  `permission.task` lists of the agents that dispatch it, the installers'
  expected-roster lines, and the README.
- Commits go straight to `main`, one commit per task, message style per
  `git log` (`feat:`, `fix:`, `docs:`, `chore:`, `agents:`). Push only
  when asked.
