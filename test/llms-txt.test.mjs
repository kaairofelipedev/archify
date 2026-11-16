import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const discovery = 'npx -y skills@latest add https://archify.si --list --full-depth';
const doctor = 'node <installed-path>/bin/archify.mjs doctor';

function read(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

function switcherAgents() {
  const start = read('docs/start.html');
  const known = start.match(/KNOWN_AGENTS = new Set\(\[([^\]]+)\]\)/);
  assert.ok(known, 'start page must name its switcher agents');
  return [...known[1].matchAll(/'([^']+)'/g)].map((match) => match[1]);
}

test('llms.txt states the package version and the bounded install', () => {
  const version = JSON.parse(read('archify/package.json')).version;
  const root = read('llms.txt');
  const site = read('docs/llms.txt');
  assert.equal(site, root);
  assert.match(root, new RegExp(`^Version: ${version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'));
  assert.match(root, /https:\/\/github\.com\/tt-a1i\/archify/);
  assert.match(root, /https:\/\/archify\.si/);
  assert.match(root, /confirm the scope before you install/i);
  assert.match(root, /exactly one skill named `archify`/);
  assert.match(root, new RegExp(discovery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.match(root, /--skill archify --agent <agent> --global --copy --yes/);
  assert.match(root, /unmanaged files/);
  assert.match(root, /Before either install command, inspect every selected agent destination/);
  assert.match(root, /stop and report the conflict before running the installer/);
  assert.match(root, new RegExp(doctor.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.match(root, /ten diagram types/i);
  assert.match(root, /one-page explainer/i);
  for (const agent of switcherAgents()) assert.match(root, new RegExp(`\\b${agent}\\b`));
  assert.ok(root.length < 4000, 'llms.txt should stay a bounded agent brief');
});
