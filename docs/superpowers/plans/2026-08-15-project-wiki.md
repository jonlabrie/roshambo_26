# Project Wiki Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `docs/wiki/` as the single maintained authority for project knowledge and work tracking, migrate all 80 memory files into it (verified, then deleted), audit the repo, and ship a lint tool that keeps it healthy.

**Architecture:** A four-shelf markdown wiki (`program/` status, `world/` as-built, `practice/` rules, `systems/` infra pointers) with `index.md` (catalog), `log.md` (append-only chronology), and `schema.md` (the contract). Karpathy-LLM-wiki operations: integrate-don't-append, index/log split, lint. The existing `docs/superpowers/` specs/plans/ledgers are the immutable raw layer — cited, never duplicated.

**Tech Stack:** Markdown + Obsidian-style `[[wikilinks]]`; Node 24 (`node --test`) for `tools/wiki/lint.mjs`. No other dependencies.

**Spec:** `docs/superpowers/specs/2026-08-15-project-wiki-design.md`

## Global Constraints

- **Memory dir** (source material, NOT in git): `/Users/jonlabrie/.claude/projects/-Users-jonlabrie-Desktop-ClaudeCode-Roshambo-26/memory/`
- **Statuses live only on `program/` pages.** World/practice/systems pages never say "next is / resume here / in progress".
- **Supersede, don't append**: pages read as current truth; chronology goes to `log.md`.
- **Cite, don't duplicate** the raw layer (`docs/superpowers/`, git history, SDD ledgers under `.superpowers/sdd/`).
- **Verification before fact**: every status/as-built claim is checked against git (`git log --oneline --all -i --grep="<topic>"`, `git log -S"<symbol>" --oneline`, file existence) before being written as fact. Place-state claims: check via Roblox Studio MCP (`get_studio_state` first; if not connected, write the claim with a literal `⚠ unverified` marker instead of as fact).
- **Delete after landing**: each memory file is `rm`'d immediately after the commit that lands its content, and its line is removed from `MEMORY.md` in the same task. No archive folder.
- **Log entry format**: `## [YYYY-MM-DD] <kind> | <title>` where kind ∈ `gate ship decision drop defect migrate lint audit`. Append-only.
- **Page frontmatter** (every wiki page):

  ```markdown
  ---
  shelf: world          # program | world | practice | systems
  updated: 2026-08-15   # absolute date, bump on every edit
  ---
  ```

  plus `status: open|closed|parked|dropped` **only** on `program/` pages.
- **Page body template** (adapt per shelf; sections may be omitted when empty, never left as stubs):

  ```markdown
  # <Name>

  <One-paragraph identity: what this is and where it lives.>

  ## As built / The rule / Current state
  <current truth>

  ## Gates & decisions
  - 2026-08-14 owner gate: <what was accepted / dropped>

  ## Raw layer
  - spec: docs/superpowers/specs/<file>.md
  - key commits: <sha> <one-liner>
  ```
- **Index line format**: `- [<Name>](<shelf>/<file>.md) — <what the page covers>` (coverage, never status words).
- **Node runs**: the login shell defaults to an old Node. Prefix every node command: `source ~/.nvm/nvm.sh && nvm use >/dev/null &&` (repo `.nvmrc` pins 24.x).
- **Never commit** `.rbxl`/`.rbxlx` (CI fails) or anything under the memory dir. Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Do not modify** `dist/`, `docs/superpowers/specs|plans/` historical documents, or any Roblox place content. The audit files findings; it does not fix (except trivial-and-safe doc sentences).

---

### Task 1: Wiki skeleton, schema, and harness integration

**Files:**
- Create: `docs/wiki/schema.md`, `docs/wiki/index.md`, `docs/wiki/log.md`
- Create (empty shelves): `docs/wiki/program/.gitkeep`, `docs/wiki/world/.gitkeep`, `docs/wiki/practice/.gitkeep`, `docs/wiki/systems/.gitkeep`
- Modify: `CLAUDE.md` (new section near the top, after "## Working Preferences")

**Interfaces:**
- Produces: the directory layout, log/index formats, and `schema.md` rules that every later task follows verbatim.

- [ ] **Step 1: Create the skeleton**

```bash
mkdir -p docs/wiki/{program,world,practice,systems}
touch docs/wiki/{program,world,practice,systems}/.gitkeep
```

- [ ] **Step 2: Write `docs/wiki/schema.md`** with exactly this content:

```markdown
# Wiki Schema

This wiki is the single authority for Roshambo project knowledge and work tracking.
Sessions read `index.md` first. The pattern is Karpathy's LLM-wiki
(spec: `docs/superpowers/specs/2026-08-15-project-wiki-design.md`), adapted.

## Shelves

- `program/` — STATUS. The only shelf where statuses live (frontmatter `status:`,
  words like "next", "open", "parked"). Boards, per-item pages, parked defects, backlog.
- `world/` — AS-BUILT. One page per structure/zone/in-game system. States what is
  built, gated, and place-only. Never says what is next.
- `practice/` — HOW WE WORK. Standing rules, recipes, traps, owner rulings.
- `systems/` — thin pointers into code/deploy/data truth the repo already records.

## Rules

1. **Statuses only on `program/` pages.**
2. **Supersede, don't append.** New truth replaces old text; chronology goes to
   `log.md`. A page must never read as an argument with its past self.
3. **Update triggers** — touch the wiki in the same commit/session as: an owner gate,
   a drop ("do not re-raise"), a program item opening/closing, a defect found or
   parked, a standing-rule correction, a place save/publish.
4. **Cite, don't duplicate.** `docs/superpowers/` specs/plans/SDD ledgers and git
   history are the immutable raw layer. Link to them; carry only synthesis and what
   they cannot record (owner decisions, place state).
5. **`⚠ unverified`** marks any claim not checked against git or the live place.
   Never launder a memory into a fact.
6. **Frontmatter**: every page has `shelf:` and `updated:` (absolute date, bumped on
   every edit); `status:` only on `program/` pages.
7. **Links** are `[[wikilinks]]` between pages; `index.md` uses markdown links.
8. **`log.md`** entries: `## [YYYY-MM-DD] <kind> | <title>`, kind ∈
   gate | ship | decision | drop | defect | migrate | lint | audit. Append-only.

## Lint (recurring)

Run `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs` —
mechanical checks (index completeness, dead wikilinks, orphans, status language
outside program/, log format, frontmatter). Then the manual pass:

- contradictions between pages
- claims superseded by newer gates/commits
- `⚠ unverified` claims that have since become checkable
- important topics mentioned on 3+ pages but lacking their own page

Run on request, and cheaply at any session close.
```

- [ ] **Step 3: Write `docs/wiki/index.md`** initial content:

```markdown
# Roshambo Wiki Index

Read this first. Rules and shelf definitions: [schema.md](schema.md).
Chronology: [log.md](log.md).

## program — status & work tracking

(populated by migration)

## world — as-built

(populated by migration)

## practice — how we work

(populated by migration)

## systems — infra pointers

(populated by migration)
```

- [ ] **Step 4: Write `docs/wiki/log.md`** initial content (use today's real date):

```markdown
# Log

Append-only. `grep "^## \[" log.md | tail -5` for recent entries.

## [2026-08-15] migrate | Wiki created; migration from memory dir begins

Spec: docs/superpowers/specs/2026-08-15-project-wiki-design.md. 80 memory files to
be reconciled in, verified against git, then deleted from the memory dir.
```

- [ ] **Step 5: Add the CLAUDE.md section** — insert after the `## Working Preferences` section:

```markdown
## Project Wiki (docs/wiki/) — read before relying on memory

`docs/wiki/` is the single authority for project knowledge and work tracking. Read
`docs/wiki/index.md` at session start before relying on auto-memory. Record project
facts (gates, decisions, statuses, as-built state, standing rules) THERE, following
`docs/wiki/schema.md` — not in the auto-memory directory. The auto-memory dir holds
only user/feedback memories about how we work together. Statuses live only under
`docs/wiki/program/`; supersede text rather than appending; log events in
`docs/wiki/log.md`.
```

- [ ] **Step 6: Commit**

```bash
git add docs/wiki CLAUDE.md
git commit -m "docs(wiki): skeleton, schema, and CLAUDE.md integration"
```

---

### Task 2: Lint tool (TDD)

**Files:**
- Create: `tools/wiki/lint.mjs`
- Test: `tools/wiki/lint.test.mjs`

**Interfaces:**
- Produces: `lint(rootDir) -> { errors: string[], warnings: string[], pageCount: number }` (named export), and a CLI (`node tools/wiki/lint.mjs [rootDir]`, default `docs/wiki`, exit 1 on errors). Every later task runs this CLI before committing.

- [ ] **Step 1: Write the failing tests** in `tools/wiki/lint.test.mjs`. Tests build throwaway fixture wikis in a temp dir:

```js
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node --test tools/wiki/`
Expected: FAIL — `Cannot find module ... lint.mjs`

- [ ] **Step 3: Implement `tools/wiki/lint.mjs`**

```js
#!/usr/bin/env node
// Wiki lint: index completeness, dead wikilinks, orphans, status language outside
// program/, log entry format, required frontmatter. See docs/wiki/schema.md.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

const SHELVES = ['program', 'world', 'practice', 'systems'];
const LOG_KINDS = 'gate|ship|decision|drop|defect|migrate|lint|audit';
const STATUS_RE = /\b(NEXT IS|IN PROGRESS|RESUME HERE|OPEN:|BLOCKED|PARKED:|TODO:)\b/;

export function lint(root) {
  const errors = [];
  const warnings = [];

  const pages = [];
  for (const shelf of SHELVES) {
    const dir = join(root, shelf);
    if (!existsSync(dir)) continue;
    for (const f of readdirSync(dir).filter((f) => f.endsWith('.md'))) {
      const path = join(dir, f);
      pages.push({ shelf, name: basename(f, '.md'), rel: `${shelf}/${f}`, path, text: readFileSync(path, 'utf8') });
    }
  }
  const names = new Set(pages.map((p) => p.name));

  // 1. index completeness both ways
  const index = readFileSync(join(root, 'index.md'), 'utf8');
  for (const p of pages) if (!index.includes(p.rel)) errors.push(`index.md missing ${p.rel}`);
  for (const m of index.matchAll(/\(((?:program|world|practice|systems)\/[^)]+\.md)\)/g))
    if (!existsSync(join(root, m[1]))) errors.push(`index.md links to missing ${m[1]}`);

  for (const p of pages) {
    // 2. dead wikilinks
    for (const m of p.text.matchAll(/\[\[([^\]|#]+)/g)) {
      const target = m[1].trim();
      if (!names.has(target)) errors.push(`${p.rel}: dead wikilink [[${target}]]`);
    }
    // 3. status confinement
    if (p.shelf !== 'program') {
      if (/^status:/m.test(p.text)) errors.push(`${p.rel}: frontmatter 'status' outside program/`);
      const line = p.text.split('\n').find((l) => STATUS_RE.test(l));
      if (line) errors.push(`${p.rel}: status language outside program/: "${line.trim()}"`);
    }
    // 4. frontmatter
    if (!/^shelf: (program|world|practice|systems)$/m.test(p.text)) errors.push(`${p.rel}: missing/bad frontmatter 'shelf'`);
    if (!/^updated: \d{4}-\d{2}-\d{2}$/m.test(p.text)) errors.push(`${p.rel}: missing/bad frontmatter 'updated'`);
    // 5. orphans (index links don't count) — warning only
    const inbound = pages.some((q) => q !== p && (q.text.includes(`[[${p.name}]]`) || q.text.includes(`[[${p.name}|`)));
    if (!inbound) warnings.push(`${p.rel}: no inbound wikilinks (orphan)`);
  }

  // 6. log format
  const log = readFileSync(join(root, 'log.md'), 'utf8');
  const entryRe = new RegExp(`^## \\[\\d{4}-\\d{2}-\\d{2}\\] (${LOG_KINDS}) \\| .+`);
  for (const line of log.split('\n').filter((l) => l.startsWith('## ')))
    if (!entryRe.test(line)) errors.push(`log.md: malformed entry "${line}"`);

  return { errors, warnings, pageCount: pages.length };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const root = process.argv[2] ?? 'docs/wiki';
  const { errors, warnings, pageCount } = lint(root);
  for (const w of warnings) console.log(`WARN  ${w}`);
  for (const e of errors) console.log(`ERROR ${e}`);
  console.log(`${errors.length} error(s), ${warnings.length} warning(s) across ${pageCount} pages`);
  process.exit(errors.length ? 1 : 0);
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node --test tools/wiki/`
Expected: 7 passing

- [ ] **Step 5: Run the CLI against the real skeleton**

Run: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs`
Expected: `0 error(s), 0 warning(s) across 0 pages`, exit 0

- [ ] **Step 6: Commit**

```bash
git add tools/wiki
git commit -m "feat(wiki): lint tool (index, wikilinks, status confinement, log format)"
```

---

### Task 3: Migrate the `program/` shelf

**Files:**
- Create: `docs/wiki/program/friends-family-baseline.md` (the board), `docs/wiki/program/item-4-merchant-row.md`, `docs/wiki/program/parked-defects.md`, `docs/wiki/program/backlog.md`
- Modify: `docs/wiki/index.md`, `docs/wiki/log.md`
- Consume+delete from memory dir (path in Global Constraints): `roshambo-roadmap.md`, `world-throw-cycle-phase.md`, `teahouse-access-control-backlog.md`, `spawn-at-teahouse-backlog.md`, `piece-b-startup-notes.md`, `roshambo-metagame-spec.md`
- Consume (partially — status/defect fragments only; files deleted in Tasks 4–6 where their main content lands): `friends-family-baseline.md` (its 花火屋 as-built content is needed by Task 4), `roshambo-round-structure.md`, `play-hud-item2.md`, `roshambo-structure-builder.md`, `roshambo-apprunner-migration.md`, `zendojo-fw11-switchback-deck.md`, `zendojo-yamadoro-lantern.md`

**Interfaces:**
- Consumes: layout + formats from Task 1; `node tools/wiki/lint.mjs` from Task 2.
- Produces: page names `friends-family-baseline`, `item-4-merchant-row`, `parked-defects`, `backlog` for later wikilinks.

- [ ] **Step 1: Read every consumed memory file in full.** Extract: statuses, open/closed/parked/dropped rulings, owner gates with dates, defects.

- [ ] **Step 2: Verify each status claim against git** before writing it as fact. At minimum:

```bash
# items 1-3 closed: confirm the closing commits exist
git log --oneline --all -i --grep="foliage" | head -5
git log --oneline --all -i --grep="hud" | head -5
git log --oneline --all -i --grep="firework" | head -5
# parked economy defects still present in code:
grep -n "optimisticConcurrency\|findOneAndUpdate" server/src/routes/apiV1.ts | head
grep -rn "validateDecorations" server/src | head
# world-throw phase seeding still Round.countDocuments at boot:
grep -rn "countDocuments" server/src | head
```

Anything that cannot be confirmed gets `⚠ unverified` on the page.

- [ ] **Step 3: Write the board** `program/friends-family-baseline.md` — frontmatter per Global Constraints with `status: open`; the 8 items each as ONE line with `status` word + link (items 4–8 open; per-item detail only for open items with real detail — item 4 gets its own page; 5–8 stay as board lines until opened); "the bar" paragraph; "Out of scope" list; cite spec `docs/superpowers/specs/2026-07-30-friends-family-baseline-design.md`.

- [ ] **Step 4: Write `program/item-4-merchant-row.md`** (`status: open`): scope from the baseline memory (4 façade shells + working shop — note 花火屋 already built; write it as plain text `hanabiya`, NOT a wikilink — the world page arrives in Task 4 and lint forbids dead links; Task 4 upgrades it to `[[hanabiya]]`), the machiya-needs-own-brainstorm note, massing location `ServerStorage.Sandbox_PARKED.MerchantMassing` (`⚠ unverified` unless Studio confirms), and the prerequisite: corridor reservations in `roblox/tools/builders/ArenaLayout.luau:210-212` are stale after the karesansui shrink.

- [ ] **Step 5: Write `program/parked-defects.md`** (`status: parked`), one section per defect, each with reproduction, fix sketch, and source citation: (a) purchase read-modify-write race; (b) `PUT /decorations` ownership check missing; (c) `RESOLVE_FAILED` returns 500; (d) onboarding empty-card layout defect (+ its confirm-first instruction); (e) world-throw TEST_MODE phase seeded from `Round.countDocuments()`; (f) play-HUD synthetic-plate-click ledger non-open (cause undetermined — do not fix on a guess); (g) round-structure offset-by-one diagnosis.

- [ ] **Step 6: Write `program/backlog.md`** (`status: open`) — one section per future item, each citing its raw-layer spec/commits: teahouse access control; spawn-at-teahouse (Piece B candidate); Piece B startup notes; meta-game spec pointer (approved 4d9b9c6, amended ef6ced9); App Runner → ECS migration (do before production); onboarding content/pacing design pass; FW11 railings/chōchin (resume Task 1 of its plan); yamadoro lantern placement/lighting; PWA throw-drum replica (parked idea).

- [ ] **Step 7: Update `index.md`** (program section, one line per page) and append to `log.md`:

```markdown
## [2026-08-15] migrate | program/ shelf: board, item-4, parked-defects, backlog
```

- [ ] **Step 8: Lint, commit, then delete the fully-consumed memory files**

```bash
source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs
git add docs/wiki && git commit -m "docs(wiki): migrate program shelf (board, item-4, parked defects, backlog)"
M=/Users/jonlabrie/.claude/projects/-Users-jonlabrie-Desktop-ClaudeCode-Roshambo-26/memory
rm "$M"/roshambo-roadmap.md "$M"/world-throw-cycle-phase.md \
   "$M"/teahouse-access-control-backlog.md "$M"/spawn-at-teahouse-backlog.md \
   "$M"/piece-b-startup-notes.md "$M"/roshambo-metagame-spec.md
```

Then remove those files' lines from `$M/MEMORY.md` (edit the file; it is not in git).

---

### Task 4: Migrate the `world/` shelf

**Files:**
- Create in `docs/wiki/world/`: `arena-square.md`, `bell-engine.md`, `hanabiya.md`, `falls-dock.md`, `switchback-deck.md`, `viewing-platform.md`, `canyon.md`, `paths.md`, `foliage.md`, `teahouses.md`, `water-audio.md`, `fireworks.md`, `day-night.md`, `round-and-hud.md`, `place-state.md`
- Modify: `docs/wiki/index.md`, `docs/wiki/log.md`
- Consume+delete: `friends-family-baseline.md` (fragments already landed in Task 3), `zendojo-arena-amplified.md`, `zendojo-bell-engine.md`, `zendojo-dock-uguisu.md`, `zendojo-fw11-switchback-deck.md`, `zendojo-viewing-platform.md`, `zendojo-canyon-redesign.md`, `zendojo-clearing-terrain.md`, `zendojo-upcanyon-watercourse.md`, `zendojo-garden-phase1.md`, `zendojo-canyon-garden.md`, `zendojo-canyon-village.md`, `zendojo-river-path.md`, `zendojo-yamadoro-lantern.md`, `zendojo-water-margin.md`, `zendojo-foliage-scatter.md`, `forest-preserve-foliage.md`, `zendojo-water-audio.md`, `roshambo-fireworks.md`, `roshambo-night-first-arena.md`, `roshambo-round-structure.md`, `play-hud-item2.md`, `roshambo-structure-builder.md`, `deck-fall-prevention-decision.md`, `roshambo-flume-revisit.md`, `roshambo-happy-sad-sides.md`, `roshambo-shoro-roof-wip.md`, `roblox-canyon-compass.md`

**Interfaces:**
- Consumes: Task 1 formats, Task 2 lint, Task 3 page names (`[[parked-defects]]`, `[[backlog]]`).
- Produces: the world page names listed above (later tasks link `[[hanabiya]]`, `[[place-state]]`, etc.).

- [ ] **Step 1: Read all consumed files.** Per-file target mapping:

| Memory file | Target page | Notes |
|---|---|---|
| zendojo-arena-amplified | `arena-square.md` | bell tower, karesansui, torii, sōrin, palette; drum caret lore from happy-sad-sides; the old "plan for next sessions" list DIES (dock built, perch → `[[backlog]]` if still unbuilt — verify) |
| zendojo-bell-engine | `bell-engine.md` | all 9 tasks done; cite commits |
| friends-family-baseline (its 花火屋/item-3 sections) | `hanabiya.md` | shop as built: frontage z36, stair/attic, noren, chōchin; dropped items (terrain cut, ishigaki) as `drop` decisions |
| zendojo-dock-uguisu | `falls-dock.md` | dock + warbler scheduler as built |
| zendojo-fw11-switchback-deck | `switchback-deck.md` | built state; railings/chōchin remainder → already in `[[backlog]]` |
| zendojo-viewing-platform | `viewing-platform.md` | verify built state via git before writing "done" |
| zendojo-canyon-redesign, -clearing-terrain, -upcanyon-watercourse, roblox-canyon-compass, roshambo-flume-revisit, zendojo-garden-phase1 | `canyon.md` | geography, compass (−Z=North), clearing, watercourse chain, creek+scoop-wheel; garden-phase1 is superseded history → one log line |
| zendojo-canyon-village, -river-path, -yamadoro-lantern | `paths.md` | trail register, CanyonPath builder, lighting; lantern placement remainder → `[[backlog]]` |
| zendojo-canyon-garden, -water-margin, -foliage-scatter, forest-preserve-foliage | `foliage.md` | curated-floor model, composition-first rule pointer to practice, scatter system, as-built groves/backdrop; manifest CSV citation |
| zendojo-water-audio | `water-audio.md` | W## naming, 17 emitters, clip IDs |
| roshambo-fireworks | `fireworks.md` | system as built + perf rules + untested global director cap noted `⚠ unverified` |
| roshambo-night-first-arena | `day-night.md` | day/night foundation; DayNightLockT clearing requirement → also `place-state.md` |
| roshambo-round-structure, play-hud-item2 | `round-and-hud.md` | OPEN 51/LOCK 2/REVEAL 7, glyph reel, drum-is-authoritative, pot indicator; defect fragments already on `[[parked-defects]]`; RISK/BANK ruling → Task 5's owner-rulings |
| roshambo-structure-builder, deck-fall-prevention-decision | `teahouses.md` | portable loadout structures, deck railing/fall-guard decision, Bay models |
| roshambo-shoro-roof-wip | (none) | verify superseded by the built shōrō roof (git grep "roof"); if so: log line only, delete |
| roshambo-happy-sad-sides | `arena-square.md` | one lore line |

- [ ] **Step 2: Verify before writing.** For every "built/done" claim, find the commit (`git log --oneline --all -i --grep="<name>"`). Try Studio: `mcp__Roblox_Studio__get_studio_state`; if connected, spot-check place-only claims (e.g. `Workspace.CanyonWorld.Structures.Chochin_Hanabiya`, `EngawaBarrier`, `ServerStorage.FoliageSnapshot_2026_08_02`) via `search_game_tree`/`inspect_instance`; if not connected, mark those `⚠ unverified`.

- [ ] **Step 3: Write `world/place-state.md`** — the page for what git cannot see: the place-only lifecycle convention (cite CLAUDE.md §Workspace organization), current unsaved/at-risk items (from arena-amplified: `NorenCloth`, `BronzePatinaFine`, `Chochin_Hanabiya`, `BellRingAnchor` — `⚠ unverified` unless Studio confirms saved), the publish checklist (clear `DayNightLockT` to 0.19, run `tools/studio/verifyWorkspaceConvention.luau`, never `rojo build` to ship), and known ServerStorage inventory (`Sandbox_PARKED`, `FoliageSnapshot_2026_08_02`, `ParkedFoliage.MossTransitions_2026_08_01`).

- [ ] **Step 4: Write the remaining pages per the mapping.** Statuses and "remaining work" go to `[[backlog]]`/`[[parked-defects]]` (Task 3 pages), never onto these pages. **Carry every owner taste/copy ruling into the target page's Gates & decisions section** (RISK/BANK no-wager-language → round-and-hud; flume "simple/tranquil" → canyon; drum caret asymmetry lore → arena-square; composition-first scatter rule → foliage) — Task 5's owner-rulings page is compiled FROM those sections, because the memory files are deleted at this task's end. Upgrade Task 3's plain-text `hanabiya` mention on item-4 to `[[hanabiya]]`.

- [ ] **Step 5: Update `index.md`; append to `log.md`**: `## [2026-08-15] migrate | world/ shelf: 15 as-built pages`

- [ ] **Step 6: Lint, commit, delete consumed memory files + their MEMORY.md lines**

```bash
source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs
git add docs/wiki && git commit -m "docs(wiki): migrate world shelf (as-built record, place-state)"
# then rm the 28 consumed files from $M and their MEMORY.md lines
```

---

### Task 5: Migrate the `practice/` shelf

**Files:**
- Create in `docs/wiki/practice/`: `flush-outside-edges.md`, `derive-from-what-it-touches.md`, `one-model-is-not-a-building.md`, `walls-register-to-structure.md`, `placement-discipline.md`, `bake-isolation.md`, `destructive-bake-guard.md`, `visible-is-not-pixels.md`, `perf-harness-contamination.md`, `toolbox-backdoor-scan.md`, `duplicated-server-constants.md`, `material-and-mesh-traps.md`, `texturing-pack-meshes.md`, `rojo-meshpart-rbxm.md`, `editablemesh-gotchas.md`, `replication-races.md`, `modal-cursor-grip.md`, `image-moderation.md`, `build-recipes.md`, `studio-tooling.md`, `blender-pipeline.md`, `misc-engine-traps.md`, `owner-rulings.md`
- Modify: `docs/wiki/index.md`, `docs/wiki/log.md`
- Consume+delete: `roblox-flush-outside-edges.md`, `roblox-derive-from-what-it-touches.md`, `roblox-one-model-is-not-a-building.md`, `roblox-walls-register-to-structure.md`, `roblox-placement-discipline.md`, `roblox-bake-isolation.md`, `roblox-destructive-bake-guard.md`, `roblox-visible-is-not-pixels.md`, `perf-harness-contamination.md`, `roblox-toolbox-backdoor-scan.md`, `roshambo-duplicated-server-constants.md`, `roblox-material-and-mesh-traps.md`, `roblox-texturing-pack-meshes.md`, `roblox-rojo-meshpart-rbxm.md`, `roblox-editablemesh-gotchas.md`, `roblox-client-replication-race.md`, `roblox-remote-event-replication-race.md`, `roblox-particle-emit-replication.md`, `roblox-modal-cursor-grip.md`, `roblox-image-moderation-foliage.md`, `zendojo-build-recipes.md`, `zendojo-ishidan-step-recipe.md`, `zendojo-organic-cobble-path.md`, `zendojo-mossy-terrain-pbr.md`, `roblox-studio-ui.md`, `roblox-studio-mcp.md`, `roblox-screencapture-camera-lock.md`, `blender-fbx-to-roblox.md`, `procedural-river-pipeline.md`, `roblox-surfacegui-textsize.md`, `roblox-flat-beam-orientation.md`, `roblox-curved-tunnel-bore.md`, `roblox-genmodels-arch-portability.md`, `zendojo-teahouse-floor-vs-pivot.md`, `roshambo-glyphs-shared.md`

**Interfaces:**
- Consumes: Tasks 1–4 page names for wikilinks.
- Produces: practice page names above; `owner-rulings` is linked from program/world pages.

- [ ] **Step 1: Read all consumed files.** Merge map (everything else migrates near-verbatim 1:1 — these rot least; keep the "**Why** / **How to apply**" voice):
  - `replication-races.md` ← client-replication-race + remote-event-replication-race + particle-emit-replication
  - `build-recipes.md` ← zendojo-build-recipes (the index) + ishidan-step-recipe + organic-cobble-path + mossy-terrain-pbr, kept as clearly-headed sections; preserve the "CONSULT FIRST before building/fixing ANY canyon path/deck/wall/railing/lantern" instruction at top
  - `studio-tooling.md` ← studio-ui + studio-mcp + screencapture-camera-lock
  - `blender-pipeline.md` ← blender-fbx-to-roblox + procedural-river-pipeline + glyphs-shared (SDF pipeline half; upload-moderation half → `image-moderation.md`)
  - `misc-engine-traps.md` ← surfacegui-textsize + flat-beam-orientation + curved-tunnel-bore + genmodels-arch-portability + teahouse-floor-vs-pivot
  - `image-moderation.md` ← image-moderation-foliage + the moderation lessons from glyphs-shared

- [ ] **Step 2: Write `practice/owner-rulings.md`** — the taste/copy rulings now carried in the Gates & decisions sections of Task 4's world pages (the source memory files are gone) plus files consumed in this task: no wager language near points (RISK/BANK ruling, cite `[[round-and-hud]]` and the play-hud raw-layer ledger); happy/sad drum asymmetry is intentional lore; "simple/tranquil" water-feature taste (flume → creek + scoop wheel); polish-where-visible > tutorialization; composition-first (scatter = background fill only); results-not-algorithms approval (from bake-isolation); one-attempt-then-owner-looks. Each ruling: one line + citation.

- [ ] **Step 3: Write the pages.** Where a rule references files/tools, verify they still exist (`ls`, `grep`) and update paths; mark anything unconfirmed `⚠ unverified`.

- [ ] **Step 4: Update `index.md`; append `## [2026-08-15] migrate | practice/ shelf: rules, recipes, traps, owner rulings` to `log.md`.**

- [ ] **Step 5: Lint, commit, delete the 35 consumed memory files + MEMORY.md lines** (same pattern as Task 3 Step 8).

---

### Task 6: `systems/` shelf, disposition sweep, MEMORY.md rewrite

**Files:**
- Create: `docs/wiki/systems/deploy.md`, `docs/wiki/systems/data.md`, `docs/wiki/systems/rojo-and-place.md`
- Modify: `docs/wiki/index.md`, `docs/wiki/log.md`, memory-dir `MEMORY.md` (full rewrite)
- Consume+delete: `roshambo-deploy-topology.md`, `roshambo-db-topology.md`, `roshambo-apprunner-migration.md`, `roblox-rojo-vs-place-state.md`

**Interfaces:**
- Consumes: all prior page names.
- Produces: `deploy`, `data`, `rojo-and-place` page names; the final slim MEMORY.md.

- [ ] **Step 1: Write the three systems pages** (thin — cite CLAUDE.md/README_DEPLOY.md rather than restating): `deploy.md` (cloud dev App Runner auto-deploys every push to the working branch — never start a local server for Studio/PWA dev; ECS migration is on `[[backlog]]`); `data.md` (one Atlas cluster, prod=`roshambo`, dev+Studio=`roshambo-dev`, no local mongo); `rojo-and-place.md` (Rojo owns exactly what `default.project.json` names; ship by publish, never `rojo build`; links `[[place-state]]`).

- [ ] **Step 2: Disposition sweep.** List the memory dir. Expected survivors (user/feedback + non-Roshambo): `MEMORY.md`, `stop-and-ask-after-each-attempt.md`, `roblox-user-units-feet-inches.md`, `roshambo-local-env-quirks.md`, `blender-mcp-setup.md`, `blender-show-in-viewport.md`, `talk-is-cheap-screenplay.md`. Any OTHER file still present is an unmigrated leak: migrate it to the correct shelf now (same verify-then-write rules) or, if it belongs with the survivors, justify in the log. Record the final disposition count in the log entry.

- [ ] **Step 3: Rewrite `MEMORY.md`** in the memory dir to exactly: first line block —

```markdown
# Memory Index

**Project state → `docs/wiki/index.md` in the repo. Read it first. Do NOT write
project facts here — gates, statuses, as-built, rules all go to docs/wiki/ per its
schema.md. This dir holds only user/feedback memories.**

- [Stop and ask after each attempt](stop-and-ask-after-each-attempt.md) — one visual attempt, then the owner looks
- [User units feet/inches](roblox-user-units-feet-inches.md) — 1 stud ≈ 1 foot; "2 inches" is not 2 studs
- [Local env quirks](roshambo-local-env-quirks.md) — nvm use before frontend npm; ancient gh CLI
- [Blender MCP setup](blender-mcp-setup.md) — official Lab MCP vs ahujasid trap; headless CLI
- [Show Blender work in the viewport](blender-show-in-viewport.md) — never deliver a render alone
- [Talk Is Cheap screenplay](talk-is-cheap-screenplay.md) — non-Roshambo side project
```

(adjust to match the actual survivor set from Step 2).

- [ ] **Step 4: Update `index.md`; append `## [2026-08-15] migrate | systems/ shelf + disposition sweep complete (N migrated, M retained)` to `log.md`.**

- [ ] **Step 5: Lint, commit, delete the 4 consumed files.**

```bash
source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs
git add docs/wiki && git commit -m "docs(wiki): systems shelf; migration disposition complete"
```

---

### Task 7: Repo audit (file findings, don't fix)

**Files:**
- Modify: `docs/wiki/program/parked-defects.md`, `docs/wiki/program/backlog.md`, `docs/wiki/world/place-state.md`, `docs/wiki/practice/studio-tooling.md`, `docs/wiki/systems/*.md`, `docs/wiki/log.md`, `docs/wiki/index.md`
- Possibly modify (trivial-and-safe fixes only): `README.md`, `README_DEPLOY.md`

**Interfaces:**
- Consumes: the whole wiki. Findings become edits to existing pages — new pages only if a finding fits no existing page.

- [ ] **Step 1: Tool census.** `ls roblox/tools/studio roblox/tools/builders roblox/tools/textures` (and any siblings). For each tool not already cited by a wiki page: one line in `practice/studio-tooling.md` under a "Dormant tools" section — what it does, whether it is one-shot-baked (safe to ignore) or live. Flag any tool whose target no longer exists.

- [ ] **Step 2: TODO/FIXME census.**

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" src server/src roblox/src roblox/tools --exclude-dir=node_modules | grep -v "dist/" | head -50
```

File real items onto `parked-defects` (bugs) or `backlog` (work); ignore idiom/false positives.

- [ ] **Step 3: Docs truth pass.** Read `README.md`, `README_DEPLOY.md`, `requirements.md` headers, `docs/superpowers/canyon/` file list. Verify headline claims (commands, URLs, service names) against the repo. Trivial-and-safe fixes (a stale sentence) may be applied directly; anything larger is filed to `backlog`. `requirements.md` divergence is already documented in CLAUDE.md — cite, don't rewrite.

- [ ] **Step 4: Config drift.** Compare: `.nvmrc` vs `package.json` engines (both roots); `docker-compose.yml` env expectations vs `server/.env` documented keys; `apprunner.yaml`/`amplify.yml` vs `systems/deploy.md`; CI workflow list (`ls .github/workflows`) vs what wiki pages claim CI checks. File mismatches.

- [ ] **Step 5: Place/ServerStorage inventory** — only if Studio is connected (`get_studio_state`): confirm the `place-state.md` inventory (Sandbox_PARKED contents, FoliageSnapshot, ParkedFoliage), clearing any `⚠ unverified` markers that now check out. If Studio is not connected, skip — leave markers.

- [ ] **Step 6: Append audit log entry** listing counts (`## [2026-08-15] audit | repo audit: N findings filed, M trivial fixes`), update `index.md` if any new page was created, lint, commit:

```bash
source ~/.nvm/nvm.sh && nvm use >/dev/null && node --test tools/wiki/ && node tools/wiki/lint.mjs
git add -A docs/wiki README.md README_DEPLOY.md
git commit -m "docs(wiki): repo audit findings filed"
```

---

### Task 8: Final lint and wrap

**Files:**
- Modify: `docs/wiki/log.md`, any page the lint pass touches

- [ ] **Step 1: Mechanical lint**

Run: `source ~/.nvm/nvm.sh && nvm use >/dev/null && node tools/wiki/lint.mjs`
Expected: 0 errors. Fix any error by editing the offending page (statuses found outside program/ MOVE to a program page, they are not deleted). Orphan warnings: link the page from a related page or justify leaving it.

- [ ] **Step 2: Manual lint per schema.md checklist** — read `index.md` end to end, then spot-read the board + every program page + 3 world pages: contradictions? statuses correct against git today? any `⚠ unverified` now checkable?

- [ ] **Step 3: The acceptance checks from the spec ("Done means")**
  - Memory dir: `ls "$M" | wc -l` ≤ 20, all survivors user/feedback (+ MEMORY.md pointer).
  - `program/` alone answers "what's next?" — read the board cold and confirm it says item 4 (or current truth).
  - `world/falls-dock.md` reads as built, with no future-work language.

- [ ] **Step 4: Close the log and commit**

```markdown
## [2026-08-15] lint | migration complete: N pages, 0 lint errors; memory dir reduced 81 → M files
```

```bash
git add docs/wiki && git commit -m "docs(wiki): final lint; migration complete"
```

- [ ] **Step 5: Push** (the working branch auto-deploys the server; these are docs/tools-only commits, safe): `git push`

