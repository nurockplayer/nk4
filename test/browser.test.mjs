import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { resolveBrowser, launchBrowser, browserNames } from '../browser.mjs';

test('default, normalized and invalid engine names', () => {
  assert.equal(resolveBrowser(''), 'chromium');
  assert.equal(resolveBrowser(' Firefox '), 'firefox');
  for (const value of ['safari', '--help', 'firefox; echo bad']) {
    assert.throws(() => resolveBrowser(value), /Unsupported browser engine/);
  }
});
for (const name of browserNames) {
  test(`launches only ${name} headlessly`, async () => {
    const browser = { close() {} };
    const engines = Object.fromEntries(browserNames.map(engine => [engine, {
      launch: async options => {
        assert.equal(engine, name === 'chrome' ? 'chromium' : name);
        assert.deepEqual(options, name === 'chrome' ? { headless: true, channel: 'chrome' } : { headless: true });
        return browser;
      },
    }]));
    assert.equal(await launchBrowser(name, engines), browser);
  });
}
test('CLI honors environment and explicit override', () => {
  const run = (...args) => spawnSync(process.execPath, ['browser.mjs', 'name', ...args], {
    encoding: 'utf8', env: { ...process.env, NK4_ENGINE: 'firefox' },
  });
  assert.equal(run().stdout.trim(), 'firefox');
  assert.equal(run('webkit').stdout.trim(), 'webkit');
  assert.equal(run('invalid').status, 1);
});
test('launch failure is propagated', async () => {
  await assert.rejects(launchBrowser('webkit', { webkit: { launch() { throw new Error('missing executable'); } } }), /missing executable/);
});
