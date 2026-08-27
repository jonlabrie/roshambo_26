import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { lint, gitContentDateOf, gitDateOf } from './lint.mjs';

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

// ===== currency checks (see docs/wiki/practice/wiki-currency.md) =====
// These need a repo and git, so both are injected: `gitDate` maps an absolute path to a
// commit date, `repoRoot` is where a cited path is resolved from. Absent injection the
// checks no-op, which is why every test above still passes untouched.

test('page committed after its own updated: date is an error', () => {
  const root = makeWiki(CLEAN);
  const { errors } = lint(root, { gitDate: (p) => (p.endsWith('dojo.md') ? '2026-08-17' : '') });
  assert.ok(errors.some((e) => e.includes('world/dojo.md') && e.includes('committed 2026-08-17')));
});

test('page committed on its updated: date is fine', () => {
  const root = makeWiki(CLEAN);
  const { errors } = lint(root, { gitDate: () => '2026-08-15' });
  assert.deepEqual(errors, []);
});

test('a cited repo path that does not exist is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nBuilt by `src/shared/Ghost.luau`. See [[board]].\n';
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(errors.some((e) => e.includes('dead code citation') && e.includes('Ghost.luau')));
});

test('cited code changed after the page was updated is a warning', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nSee `tools/wiki/lint.mjs`. See [[board]].\n';
  const { errors, warnings } = lint(makeWiki(wiki), {
    repoRoot: process.cwd(),
    gitDate: (p) => (p.endsWith('lint.mjs') ? '2026-08-18' : '2026-08-15'),
  });
  assert.deepEqual(errors, []);
  assert.ok(warnings.some((w) => w.includes('re-read') && w.includes('lint.mjs')));
});

test('cited code older than the page is silent', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nSee `tools/wiki/lint.mjs`. See [[board]].\n';
  const { warnings } = lint(makeWiki(wiki), {
    repoRoot: process.cwd(),
    gitDate: (p) => (p.endsWith('lint.mjs') ? '2026-08-01' : '2026-08-15'),
  });
  assert.ok(!warnings.some((w) => w.includes('re-read')));
});

test('a deliberately-absent citation is exempted by lint-ok on its line', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + '# Dojo\n`src/shared/Ghost.luau` never existed <!-- lint-ok -->\nSee [[board]].\n';
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(!errors.some((e) => e.includes('dead code citation')));
});

// ===== staleness blocks past the grace window (2026-08-26) =====
//
// ⚠ These exist because staleness used to be a WARNING, and warnings do not get cleared: fifteen
// had accumulated, eight of them eleven days old, while 60 of the previous 77 wiki commits were
// corrections of things already written. The escape hatch has to work, or this becomes noise
// somebody disables — so it is tested as carefully as the block itself.
//
// Cites a REAL file with repoRoot = cwd, matching the tests above: a citation that does not resolve
// is reported as a dead citation and never reaches the staleness check at all.

const stale = ({ moved, checked }) => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world', checked ? `checked: ${checked}\n` : '') +
    '# Dojo\nSee `tools/wiki/lint.mjs`. See [[board]].\n';
  return lint(makeWiki(wiki), {
    repoRoot: process.cwd(),
    gitDate: (f) => (f.endsWith('lint.mjs') ? moved : '2026-08-01'),
  });
};

test('code changed long after the page was verified is an ERROR, not a warning', () => {
  const { errors, warnings } = stale({ moved: '2026-08-30' }); // page updated 2026-08-15 => 15d
  assert.ok(errors.some((e) => e.includes('re-read') && e.includes('lint.mjs')));
  assert.ok(!warnings.some((w) => w.includes('lint.mjs')));
});

test('inside the grace window it stays a warning — same-session work must not trip it', () => {
  const { errors, warnings } = stale({ moved: '2026-08-17' }); // 2 days
  assert.ok(!errors.some((e) => e.includes('lint.mjs')));
  assert.ok(warnings.some((w) => w.includes('re-read') && w.includes('lint.mjs')));
});

test("'checked:' clears staleness without claiming the page changed", () => {
  // ⚠ THE WHOLE POINT OF A SEPARATE FIELD. Bumping `updated:` would silence this too, but it would
  // assert the page was EDITED when all that happened is somebody re-read it and found it right.
  const { errors } = stale({ moved: '2026-08-30', checked: '2026-08-31' });
  assert.ok(!errors.some((e) => e.includes('lint.mjs')));
});

test("a 'checked:' older than the code change does NOT clear it", () => {
  // Otherwise one stale acknowledgement silences a page forever.
  const { errors } = stale({ moved: '2026-08-30', checked: '2026-08-20' });
  assert.ok(errors.some((e) => e.includes('re-read') && e.includes('lint.mjs')));
});

test('a malformed checked: date is an error in its own right', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world', 'checked: last tuesday\n') + '# Dojo\nSee [[board]].\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes("bad frontmatter 'checked'")));
});

// ⚠ THE HATCH HAD TO BE OPENABLE. Shipped 2026-08-26 (7fada0b), `checked:` was unusable by
// construction: adding it COMMITS the page, which advances the page's commit date, which trips
// check 7 -- whose only remedy is bumping `updated:`, the exact lie `checked:` exists to avoid.
// Seven pages failed the moment the feature that created them landed. Check 7 must therefore ask
// when the page's BODY last moved, not when its file last moved.
test("a commit that only bumps 'checked:' does not trip check 7", () => {
  const root = makeWiki(CLEAN);
  const { errors } = lint(root, {
    gitDate: () => '2026-08-31', // the file moved today...
    gitContentDate: () => '2026-08-15', // ...but its body did not
  });
  assert.deepEqual(errors, []);
});

test('a commit that changes the body still trips check 7', () => {
  // The hatch must not become a blanket amnesty: this is the check earning its keep.
  const root = makeWiki(CLEAN);
  const { errors } = lint(root, {
    gitDate: () => '2026-08-31',
    gitContentDate: (p) => (p.endsWith('dojo.md') ? '2026-08-31' : '2026-08-15'),
  });
  assert.ok(errors.some((e) => e.includes('world/dojo.md') && e.includes('committed 2026-08-31')));
  // ⚠ and the OTHER page must stay silent. Without this line the assertion above is satisfied by
  // the very bug it guards -- pre-fix, check 7 fired on every page, so "dojo errors" was vacuous.
  assert.ok(!errors.some((e) => e.includes('program/board.md')));
});

// ⚠ THE TWO TESTS ABOVE INJECT `gitContentDate`, so they prove check 7 is WIRED to it and nothing
// more -- both survived mutating the real helper's body. This one drives `gitContentDateOf`
// against an actual repo, because that is where the bug lived.
test('gitContentDateOf ignores a checked:-only commit and reports the body date', () => {
  const repo = mkdtempSync(join(tmpdir(), 'wikigit-'));
  const page = join(repo, 'page.md');
  const git = (args, date) =>
    execFileSync('git', args, {
      cwd: repo,
      stdio: 'ignore',
      env: { ...process.env, GIT_AUTHOR_DATE: date, GIT_COMMITTER_DATE: date,
             GIT_AUTHOR_NAME: 'T', GIT_AUTHOR_EMAIL: 't@t', GIT_COMMITTER_NAME: 'T',
             GIT_COMMITTER_EMAIL: 't@t' },
    });
  git(['init', '-q', '-b', 'main']);

  writeFileSync(page, '---\nshelf: world\nupdated: 2026-08-15\n---\n# Page\nbody\n');
  git(['add', 'page.md']);
  git(['commit', '-qm', 'body'], '2026-08-15T12:00:00');

  // the checked: bump -- a real commit, on a later day, touching only that line
  writeFileSync(page, '---\nshelf: world\nupdated: 2026-08-15\nchecked: 2026-08-26\n---\n# Page\nbody\n');
  git(['add', 'page.md']);
  git(['commit', '-qm', 'checked'], '2026-08-26T12:00:00');

  assert.equal(gitDateOf(page), '2026-08-26'); // the FILE moved today
  assert.equal(gitContentDateOf(page), '2026-08-15'); // the BODY did not

  // and a real edit is seen again, so the hatch is not a blanket amnesty
  writeFileSync(page, '---\nshelf: world\nupdated: 2026-08-15\nchecked: 2026-08-26\n---\n# Page\nEDITED\n');
  git(['add', 'page.md']);
  git(['commit', '-qm', 'edit'], '2026-08-27T12:00:00');
  assert.equal(gitContentDateOf(page), '2026-08-27');
});

// ===== checks 10-13: the mechanical sweeps, added 2026-08-27 =====
// ⚠ ALL FOUR CAME OUT OF A MANUAL FULL-WIKI AUDIT that found 13 rotten line citations and
// verified 105 commit hashes by hand. They are here so the CHEAP pass is sufficient for the
// mechanical layer, leaving reading for prose — which is the only thing that catches the rest.

test('a cited commit hash that does not resolve is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nBuilt in `deadbee` — see [[board]].\n';
  const { errors } = lint(makeWiki(wiki), { commitExists: (h) => h === 'cafef00' });
  assert.ok(errors.some((e) => e.includes('world/dojo.md') && e.includes('deadbee')));
});

test('a resolvable hash is silent, and ASSET IDS ARE NOT HASHES', () => {
  // ⚠ The manual sweep's first run reported 36 "missing hashes"; all but one were Roblox asset
  // ids (pure decimal) and an AWS service id. A check that cries wolf on 35 of 36 gets ignored.
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + '# Dojo\n`cafef00` shipped it; texture `140172233879343`; drum `0123456789`.\n[[board]]\n';
  const { errors } = lint(makeWiki(wiki), { commitExists: (h) => h === 'cafef00' });
  assert.deepEqual(errors, []);
});

test('a cited code symbol that exists nowhere in the repo is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\n`GameRules.deriveWorldThrow` and `Bird.vanished`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { sourceText: () => 'function deriveWorldThrow() {}' });
  assert.ok(errors.some((e) => e.includes('Bird.vanished')));
  assert.ok(!errors.some((e) => e.includes('deriveWorldThrow')));
});

test('a file extension is not a symbol', () => {
  // `main.server.luau` and `apprunner.yaml` are paths; the leaf must not be looked up as code.
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\n`main.server.luau` and `vite.config.ts`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { sourceText: () => '' });
  assert.deepEqual(errors, []);
});

test('a constant whose wiki value disagrees with the code is an error', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\n`MIN_STREAK` = 3 governs it. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { sourceText: () => 'MIN_STREAK = 2\n' });
  assert.ok(errors.some((e) => e.includes('MIN_STREAK') && e.includes('3') && e.includes('2')));
});

test('a constant the wiki NARRATES as retired is exempt on its line', () => {
  // ⚠ THE ONE FALSE POSITIVE THE MANUAL SWEEP HIT. `one-model-is-not-a-building.md` says
  // "MIN_SHORO_GAP = 5.0 was a floor invented here" — the page is CORRECT and telling the story
  // of a wrong value. Without an exemption the check punishes exactly the writing we want.
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + '# Dojo\n`MIN_STREAK` = 3 was wrong. <!-- lint-ok: narrating a retired value -->\n[[board]]\n';
  const { errors } = lint(makeWiki(wiki), { sourceText: () => 'MIN_STREAK = 2\n' });
  assert.deepEqual(errors, []);
});

test('a line-number citation is an error, because they rot silently', () => {
  // 8 of 9 in parked-defects.md were wrong while the page carried a `checked:` stamp. Symbol
  // names survive a refactor; line numbers do not, and a stale one costs a reader their trust.
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nSee `server/src/wallet.ts:42`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki));
  assert.ok(errors.some((e) => e.includes('wallet.ts:42') && /line number/i.test(e)));
});

test('a bare path with no line number is still fine', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] = FM('world') + '# Dojo\nSee `tools/wiki/lint.mjs`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(!errors.some((e) => /line number/i.test(e)));
});

test("this test file is not read as repo source, or it disarms the checks it guards", () => {
  // ⚠ REGRESSION, found 2026-08-27. `sourceTextOf` walked the whole repo for .mjs and slurped
  // THIS FILE, so every fixture string and every explanatory comment here counted as code.
  // The exemption test above quotes "MIN_SHORO_GAP = 5.0" in its comment; check 12 duly found a
  // 5.0 for that constant, matched the wiki's value, and passed `one-model-is-not-a-building.md`
  // -- whose real code value is 9.0. The test defeated the check it was written to guard, and
  // the page it was written about never needed its exemption.
  //
  // The sentinel below appears in no other file in the repo, so a lint that can see it is
  // reading this file as source again.
  const SENTINEL_NOT_IN_ANY_SOURCE = 'ZZQX_LINT_SELF_CONTAMINATION_SENTINEL';
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + `# Dojo\n\`${SENTINEL_NOT_IN_ANY_SOURCE}\` is cited. [[board]]\n`;
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(
    errors.some((e) => e.includes(SENTINEL_NOT_IN_ANY_SOURCE) && /exists nowhere/.test(e)),
    'check 11 should report the sentinel as a phantom symbol; if it does not, lint.test.mjs is ' +
      'being read as source again and checks 11 and 12 are silently disarmed'
  );
});

test('a dead .superpowers/ ledger citation is caught like any other path', () => {
  // ⚠ CITE_RE anchored on roblox|server|src|tools|docs|shared-fixtures, so the 11 `.superpowers/`
  // citations across 7 pages were INVISIBLE to check 8 — including one naming a ledger that was
  // never created. The directory was also gitignored, so no clone could resolve any of them.
  // Both fixed 2026-08-27: the markdown is committed, and the prefix is now a known root.
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + '# Dojo\nLedger `.superpowers/sdd/never-existed/progress.md`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(errors.some((e) => e.includes('never-existed') && /citation|does not exist/i.test(e)));
});

test('a .superpowers/ ledger that DOES exist is silent', () => {
  const wiki = structuredClone(CLEAN);
  wiki.pages['world/dojo.md'] =
    FM('world') + '# Dojo\nLedger `.superpowers/sdd/progress.md`. [[board]]\n';
  const { errors } = lint(makeWiki(wiki), { repoRoot: process.cwd() });
  assert.ok(!errors.some((e) => e.includes('.superpowers')));
});
