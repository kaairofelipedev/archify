import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const scriptPath = path.join(here, '..', 'bin', 'install-windows.ps1');
const script = fs.readFileSync(scriptPath, 'utf8');

test('Windows setup script uses the Kalainne installer and the fork', () => {
  assert.match(script, /https:\/\/github\.com\/kaairofelipedev\/archify\.git/);
  assert.match(script, /integrations\/kalainne\/bin\/install\.mjs/);
  assert.match(script, /install',\s*'--scope',\s*'user'/);
  assert.match(script, /'doctor'/);
  assert.match(script, /integrations\/kalainne\/bin\/bootstrap\.mjs/);
  assert.match(script, /'--with-user'/);
  assert.match(script, /'--home', \$env:USERPROFILE/);
  assert.match(script, /OpenJS\.NodeJS\.LTS/);
  assert.match(script, /npx/);
  assert.match(script, /tt-a1i\/archify/);
  assert.doesNotMatch(script, /targets\.json'\)[\s\S]*git add/);
  assert.equal(script.includes('ghp_'), false);
  assert.equal(script.charCodeAt(0), 0xfeff);
});
