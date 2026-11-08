import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
const zshAvailable = spawnSync('zsh', ['--version']).status === 0;
const run = script => spawnSync('zsh', ['-f', '-c', `source ./nk4.zsh; ${script}`], { encoding: 'utf8' });
test('zsh rejects a missing engine argument', { skip: !zshAvailable }, () => {
  for (const args of ['--browser', '--browser=', '--browser --dry-run', '--engine', '--engine=', '--engine --dry-run']) {
    assert.equal(run(`nk4 https://example.com ${args}`).status, 1);
  }
});
test('zsh passes engine separately from cookie source', { skip: !zshAvailable }, () => {
  const result = run(`
    _nk4_ensure_deps() { print -u2 -- "engine:$1"; }
    node() {
      if [[ "$1" == "$NK4_SCRIPT" ]]; then
        [[ "$3" == "chromium" ]] || return 9
        print -r -- '{"title":"fixture","m3u8Url":"https://example.com/video.m3u8"}'
      else
        command node "$@"
      fi
    }
    NK4_BROWSER=firefox NK4_ENGINE=webkit nk4 https://example.com --browser chromium --dry-run
  `);
  assert.equal(result.status, 0);
  assert.match(result.stderr, /engine:chromium/);
  assert.match(result.stdout, /--cookies-from-browser firefox/);
});
test('X route still bypasses Playwright', { skip: !zshAvailable }, () => {
  const result = run(`_nk4_download_x() { print -- "x:$2"; }; _nk4_ensure_deps() { return 99; }; NK4_BROWSER=firefox nk4 https://x.com/user/status/123 --browser webkit --dry-run`);
  assert.equal(result.status, 0);
  assert.match(result.stdout, /x:firefox/);
});
test('failed probe installs only chosen engine, then stops on a second failure', { skip: !zshAvailable }, () => {
  const result = run(`
    NK4_PW=.
    node() {
      if [[ "$2" == name ]]; then print -- firefox; return 0; fi
      print -u2 -- "probe:$3"
      return 1
    }
    pnpm() { print -u2 -- "install:$*"; }
    _nk4_ensure_deps firefox
  `);
  assert.equal(result.status, 1);
  assert.deepEqual(result.stderr.trim().split('\n'), [
    'probe:firefox', 'install:exec playwright install firefox', 'probe:firefox',
  ]);
});

test('engine alias supports equals syntax and last explicit option wins', { skip: !zshAvailable }, () => {
  for (const args of ['--engine chrome', '--engine=chrome', '--browser firefox --engine chrome', '--engine firefox --browser=chrome']) {
    const result = run(`_nk4_ensure_deps() { print -- "engine:$1"; return 1; }; NK4_ENGINE=webkit nk4 https://example.com ${args}`);
    assert.match(result.stdout, /engine:chrome/);
  }
});
test('Chrome failure never downloads a browser; Chromium uses only-shell', { skip: !zshAvailable }, () => {
  for (const engine of ['chrome', 'chromium']) {
    const result = run(`
      NK4_PW=.
      node() { if [[ "$2" == name ]]; then print -- "$3"; return 0; fi; return 1; }
      pnpm() { print -u2 -- "$*"; }
      _nk4_ensure_deps ${engine}
    `);
    assert.equal(result.status, 1);
    assert.equal(result.stderr.trim(), engine === 'chrome' ? '' : 'exec playwright install --only-shell chromium');
  }
});
test('missing project dependencies use pnpm install from project directory', { skip: !zshAvailable }, () => {
  const result = run(`
    NK4_PW=/nonexistent/nk4-dependencies
    node() { if [[ "$2" == name ]]; then print -- firefox; fi; return 0; }
    pnpm() { [[ "$PWD" == "$NK4_DIR" && "$*" == install ]]; }
    cd /tmp
    _nk4_ensure_deps firefox
  `);
  assert.equal(result.status, 0);
});
