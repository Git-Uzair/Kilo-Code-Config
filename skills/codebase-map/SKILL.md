---
name: codebase-map
description: >
  Free AST symbol map of a repository with `kopipasta map --json` - the first move
  when exploring unfamiliar code, locating where a symbol or behaviour
  lives, checking whether a helper already exists, or sizing which files a
  change touches. Also bundles several files into one payload with
  `kopipasta ask --dry-run` (no model, no cost), and triages a whole repo in
  one call with `kopipasta ask -q "..." --json` when a provider key is
  configured. Use it BEFORE opening files to find out which files matter, on
  any repo you do not already know by heart, and before writing a new helper
  in an unfamiliar module. Do NOT use it as a substitute for reading the
  lines you are about to change or cite.
license: MIT
---

# Codebase map

Reading files to discover which files matter spends the context you needed
them for. `kopipasta map --json` prints the repository's symbol skeleton locally -
no model call, no network, no cost, nothing written - so you decide *what to
read* before you decide *what to pay for*.

This skill covers three moves. Move 1 is free and safe everywhere. Move 2 is
free and writes session files. Move 3 spends money and needs a key.

## Before anything: two hard rules

1. **Never run bare `kopipasta`.** With no verb it launches an interactive
   TUI and your shell call never returns. Always name a verb: `map`, `ask`,
   `session`, `config`.
2. **Export `KOPIPASTA_NONINTERACTIVE=1`** in the same command when you are
   unattended, so anything that would prompt exits instead of waiting.

Check the tool is the right generation:

```powershell
kopipasta map --help          # PowerShell
```
```bash
kopipasta map --help          # bash
```

- First line `usage: kopipasta map` -> good, 0.70.0 or newer.
- First line `usage: kopipasta` (with `-t TASK`, `--reset-template`) -> too
  old, the verbs do not exist yet.
- `kopipasta: command not found` -> not installed.

Install or upgrade:

```bash
uv tool install --force kopipasta     # preferred
pip install --upgrade kopipasta       # fallback
```

Cannot install it? Say so in your report and fall back to a narrow `glob`
plus anchored `grep`. Never invent output you did not run.

Run it from the repository root: the project root is resolved by walking up
for `.git`, and `.gitignore` is read from the current directory.

## Move 1 - map first (free, writes nothing)

```bash
kopipasta map --json                          # whole repo, JSON
kopipasta map --json src/auth                 # one subsystem
kopipasta map --json > map.json               # redirect, then parse/grep it
kopipasta map --json --budget 40k src         # cap the size
kopipasta map --json -x 'tests/**' src        # exclude, applied last, wins
kopipasta map --json --changed                # only the working-tree changes
kopipasta map --json --changed-since main     # only what this branch touched
```

`--json` (the default in this setup) outputs a single JSON object:

```json
{"ok": true, "files": 128, "with_symbols": 96, "symbols": 812,
 "chars": 41233, "est_tokens": 10308,
 "map": {"src/auth/tokens.py": ["def validate(token: str) -> bool  # ..."]},
 "path_only": ["src/big_generated.py"], "unmatched": []}
```

`path_only` lists files the `--budget` demoted: they are still named, with
no symbols. Nothing is ever silently dropped, and a selector that matched
nothing is reported rather than ignored.

Omitting `--json` returns text output with one line per file, its symbols
indented four spaces:

```text
src/auth/tokens.py
    def validate(token: str) -> bool  # Reject expired tokens.
    class TokenStore(Base) [get, put, purge]  # Backing store.
src/auth/keys.bin
```

A file with no line under it has no extractable symbols - **not** an empty
file. Symbols are extracted for `.py`, `.js`, `.jsx`, `.ts`, `.tsx` only.
For Go, Rust, Java, C#, PHP and everything else, `map` still lists the file,
so the output is a filtered file tree: useful, but not a symbol index. Say
which you got.

**Then read narrowly.** The map names candidates; it is not evidence. Open
the 2-5 files it points at with the `read` tool, by line ranges, and never
cite a `path:line` you have not seen. Piping a whole-repo map into your
context defeats the purpose - for a large repo, redirect to a file and grep
that file instead:

```bash
kopipasta map --json > map.json
```

## Move 2 - bundle several files in one call (free, writes `.kopipasta/`)

When you genuinely need three or more whole files, assemble them in one
payload instead of N tool calls:

```bash
kopipasta ask -e src/auth/tokens.py -e src/auth/session.py \
              -r 'tests/test_auth*.py' -m 'src/**/*.py' \
              -q "Trace validation to refresh." --dry-run
```

`--dry-run` calls no model and needs no API key (it is `--backend none`).
Without `--json`, **stdout is the assembled payload itself** - project tree,
then the files, with `-e/-r` rendered whole, `-m` as skeletons and `-s` as
first-50-lines. With `--json`, stdout is a receipt and `request` names the
file to read:

```json
{"ok": true, "session": "2026-08-19-0e5f", "turn": 1, "mode": "triage",
 "request": ".kopipasta/sessions/2026-08-19-0e5f/001-request.md",
 "sent": {"edit": 2, "ref": 3, "map": 380, "demoted": 0},
 "est_input_tokens": 41233, "dry_run": true}
```

Be honest about what this buys: **fewer round-trips and one consistent
snapshot, not fewer content tokens.** The token saving comes from choosing
the cheap roles - `-m` skeleton, `-s` snippet - over full content.

It writes `.kopipasta/sessions/<id>/` into the repository root. You cannot
delete it (`rm` is denied), so: stage files explicitly, never `git add -A`
or `git add .`, and mention the leftover directory in your report.

## Move 3 - triage a whole repo in one call (costs money, needs a key)

A separate process with its own large, disposable context reads the repo and
hands back pointers, so your own context stays clean:

```bash
kopipasta ask --all -q "Where is rate limiting enforced?" --json
```

The default mode is `triage`; the answer carries `hypothesis`,
`relevant_files` (each with `why` and `confidence`), `suggested_selection`
(the minimal set to load in full next) and `missing_context` (what the model
needed and did not get - read it, it is the honest part). Feed it straight
back:

```bash
kopipasta ask --from-file selection.txt -m 'src/**/*.py' \
              -q "Trace the path from validation to refresh." --json
```

This path is opt-in and unconfigured by default. Confirm before using it:

```bash
kopipasta config --show     # prints what resolved and whether a key is set
```

Needs `~/.config/kopipasta/config.toml` (`[ask] provider/model`) plus
`GEMINI_API_KEY`, `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` - note these are
*not* the variables Kilo itself uses. **Exit 2 means no usable backend: do
not retry, fall back to Move 1 and say the oracle was unavailable.** Do not
spend a paid call without a stated reason.

## Selectors (shared by `map` and `ask`)

| Flag | In `ask` | In `map` |
|---|---|---|
| `-e, --edit PATTERN` | full content, editable | skeleton |
| `-r, --ref PATTERN` | full content, read-only | skeleton |
| `-m, --map PATTERN` | AST skeleton | skeleton |
| `-s, --snippet PATTERN` | first 50 lines | skeleton |
| `-x, --exclude PATTERN` | dropped, applied last | dropped |
| `--all` | every non-ignored file | every non-ignored file |
| `--changed` | git working tree, incl. untracked | same |
| `--changed-since REF` | `git diff --name-only REF...HEAD` | same |
| `--from-file PATH` | newline-delimited paths | same |

Repeatable and order-independent; the most detailed role wins, so
`-m '**/*.py' -e src/api.py` skeletons the tree and sends that one file
whole. Globs, directories and literal paths all work, and `@file` reads
patterns from a file. `map` renders everything as a skeleton whatever flag
selected it - that is the verb's whole point. `.gitignore` and binary
filtering always apply.

Older builds may name `-e/--edit` as `-p/--pin`. If an example fails with a
usage error, run `kopipasta ask --help` and use whichever your build shows.

## Exit codes

| Code | Meaning | Do |
|---|---|---|
| 0 | success | continue |
| 1 | usage or configuration error | fix the command, do not retry blind |
| 2 | no usable backend (no key) | fall back to `map`; never retry |
| 3 | backend error or timeout | retry once if `--json` says `retryable` |
| 6 | over `--strict-budget` | narrow the selection |
| 8 | needed a human, none attached | state what it asked for |

## Scope

- `kopipasta apply` is **not** part of this skill. Kilo's `edit`/`write`
  tools own file mutation; a second patcher is a second way to corrupt a
  file.
- In a read-only role (verifier), `map` is allowed - it writes nothing and
  calls nothing. `ask` is not: it writes `.kopipasta/` into the tree.
- The map is a hypothesis generator. Evidence is still a file you read or a
  command you ran.
