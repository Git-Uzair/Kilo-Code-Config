// Kilo launchers for herdr (README "Herdr"). The installers copy this file
// next to herdr's config.toml, whose keys run it as
//   node -e "require(<this file>)" tab|worktree|folder
// and the optional `hk` shell function runs `node kilo.cjs open [folder]`.
// Node only: Kilo already requires it, on Windows and macOS alike.
'use strict';
const { execFileSync, spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const readline = require('node:readline');

const bin = process.env.HERDR_BIN_PATH || 'herdr';
// argv is [node, mode, arg] under `node -e`, [node, file, mode, arg] when run directly
const [mode, arg] = process.argv.slice(require.main === module ? 2 : 1);

const herdr = (args) =>
  execFileSync(bin, args, { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
const json = (args) => JSON.parse(herdr(args));

// `pane run` writes to the pane at once, with no readiness check, so wait
// for the new shell's first output before typing into it.
function startKilo(created) {
  const pane = created.result.root_pane.pane_id;
  try { herdr(['pane', 'wait-output', pane, '--regex', '\\S', '--timeout', '15000']); } catch {}
  herdr(['pane', 'run', pane, 'kilo']);
}

const openFolder = (dir) =>
  startKilo(json(['workspace', 'create', '--cwd', dir, '--label', path.basename(dir) || dir, '--focus']));

const home = (p) => p.replace(/^~(?=$|[\\/])/, os.homedir());

function resolveDir(input) {
  const dir = path.resolve(home(input.trim().replace(/^"(.*)"$/, '$1')));
  if (!fs.statSync(dir, { throwIfNoEntry: false })?.isDirectory()) throw new Error(`Not a folder: ${dir}`);
  return dir;
}

function serverUp() {
  try { herdr(['workspace', 'list']); return true; }
  catch (err) { if (String(err.stderr).includes('server_not_running')) return false; throw err; }
}

// Tab completion for folder names, case-insensitive, dot-folders on request.
function completeDirs(line) {
  const cut = Math.max(line.lastIndexOf('/'), line.lastIndexOf('\\')) + 1;
  const head = line.slice(0, cut);
  const stem = line.slice(cut).toLowerCase();
  try {
    const hits = fs.readdirSync(home(head) || '.', { withFileTypes: true })
      .filter((e) => e.isDirectory() && e.name.toLowerCase().startsWith(stem)
        && (stem.startsWith('.') || !e.name.startsWith('.')))
      .map((e) => head + e.name + path.sep);
    return [hits, line];
  } catch { return [[], line]; }
}

// One prompt line; resolves '' on Esc, ctrl+c or end of input.
function ask(question, prefill = '', completer) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout, completer });
    let answer = '';
    rl.on('close', () => resolve(answer));
    rl.on('SIGINT', () => rl.close());
    process.stdin.on('keypress', (_, key) => key?.name === 'escape' && rl.close());
    rl.question(question, (a) => { answer = a; rl.close(); });
    if (prefill) rl.write(prefill);
  });
}

const modes = {
  // ctrl+q a: new tab in the focused workspace
  tab() {
    const ws = process.env.HERDR_ACTIVE_WORKSPACE_ID;
    startKilo(json(['tab', 'create', ...(ws ? ['--workspace', ws] : []), '--focus']));
  },
  // ctrl+q shift+a: new worktree of the focused workspace's repo
  async worktree() {
    const branch = (await ask('Branch for the new worktree: ')).trim();
    if (!branch) return;
    const ws = process.env.HERDR_ACTIVE_WORKSPACE_ID;
    const from = ws ? ['--workspace', ws] : ['--cwd', process.cwd()];
    startKilo(json(['worktree', 'create', ...from, '--branch', branch, '--focus']));
  },
  // ctrl+q f: any folder as a new workspace, starting from the parent folder
  async folder() {
    const here = process.env.HERDR_ACTIVE_PANE_CWD || process.cwd();
    const answer = await ask('Folder to open: ', path.join(path.dirname(here), path.sep), completeDirs);
    if (answer.trim()) openFolder(resolveDir(answer));
  },
  // hk: from any terminal. With no server running, `herdr` below starts one
  // and restores the saved session instead.
  open() {
    const dir = resolveDir(arg || '.');
    if (serverUp()) openFolder(dir);
    if (process.env.HERDR_ENV !== '1') spawnSync(bin, [], { stdio: 'inherit', cwd: dir });
  },
};

function message(err) {
  try { return JSON.parse(err.stderr).error.message; } catch { return String(err.message || err); }
}

Promise.resolve()
  .then(() => {
    if (!Object.hasOwn(modes, mode)) throw new Error(`usage: kilo.cjs ${Object.keys(modes).join('|')} [folder]`);
    return modes[mode]();
  })
  .then(() => process.exit(0), async (err) => {
    const text = message(err);
    if (mode === 'tab') {
      // runs detached from any terminal, so report through herdr
      try { herdr(['notification', 'show', 'Kilo launcher failed', '--body', text]); } catch {}
    } else {
      console.error(text);
      if (mode !== 'open') await ask('Press Enter to close ');
    }
    process.exit(1);
  });
