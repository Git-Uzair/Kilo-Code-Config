# AGENTS.md

Facts every agent needs when working in THIS repository. Read once, trust,
do not re-derive.

- This repo is prose and configuration: the Kilo CLI global config
  (`config/kilo.jsonc`), standing instructions (`config/instructions.md`),
  agent prompts (`config/agents/*.md`), installers, and one local skill
  (`skills/codebase-map/`). Nothing here executes at runtime except the
  installers.
- There is NO test suite, NO build, and NO lint command - and none should
  ever be bootstrapped. Changes here are verified by reading the diff
  against the request. The DIRECT lane with @verifier-lite is the right
  depth for almost everything in this repo.
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
  (or copy the changed file over manually when asked).
- Commits go straight to `main`, one commit per task, message style per
  `git log` (`feat:`, `fix:`, `docs:`, `chore:`, `agents:`). Push only
  when asked.
