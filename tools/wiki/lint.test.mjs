import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { lint } from './lint.mjs';

const FM = (shelf, extra = '') => `---\nshelf: ${shelf}\nupdated: 2026-08-15\n${extra}---\n`;

function makeWiki({ indexLines, pages, log }) {
  const root = mkdtempSync(join(tmpdir(), 'wiki-'));
  for (const shelf of ['program', 'world', 'practice', 'systems']) mkdirSync(join(root, shelf));
  writeFileSync(join(root, 'index.md'), `# Index\n${indexLines.join('\n')}\n`);
  writeFileSync(join(root, 'log.md'), `# Log\n${log ?? '## [2026-08-15] migrate | seed\n'}`);
  for (const [rel, text] of Object.entries(pages)) writeFileSync(join(root, rel), text);
  return root;
}

const CLEAN = {
  indexLines: ['- [Board](program/board.md) — items', '- [Dojo](world/dojo.md) — the arena'],
  pages: {
    'program/board.md': FM('program', 'status: open\n') + '# Board\nSee [[dojo]].\n',
    'world/dojo.md': FM('world') + '# Dojo\nBuilt. See [[board]].\n',
  },
};

test('clean wiki has no errors', () => {
  const { errors } = lint(makeWiki(CLEAN));
  assert.deepEqual(errors, []);
});

test('dead wikilink is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nSee [[ghost-page]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('dead wikilink') && e.includes('ghost-page')));
});

test('page missing from index is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['practice/rule.md'] = FM('practice') + '# Rule\nSee [[dojo]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('index.md missing') && e.includes('practice/rule.md')));
});

test('status language outside program/ is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nRESUME HERE next session. See [[board]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('status language')));
});

test('frontmatter status outside program/ is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world', 'status: open\n') + '# Dojo\nSee [[board]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes("frontmatter 'status'")));
});

test('colon-form status language outside program/ is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nTODO: fix later. See [[board]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('status language')));
});

test('malformed log entry is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.log = '## [2026-08-15] vibes | not a kind\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('malformed')));
});

test('page with no inbound wikilink is a warning, not an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.indexLines.push('- [Loner](systems/loner.md) — alone');
  wiki.pages['systems/loner.md'] = FM('systems') + '# Loner\nNo one links here.\n';
  const { errors, warnings } = lint(makeWiki(wiki));
  assert.deepEqual(errors, []);
  assert.ok(warnings.some((w) => w.includes('loner') && w.includes('orphan')));
});
