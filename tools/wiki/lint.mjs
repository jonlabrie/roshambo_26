#!/usr/bin/env node
// Wiki lint: index completeness, dead wikilinks, orphans, status language outside
// program/, log entry format, required frontmatter. See docs/wiki/schema.md.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { join, basename, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const SHELVES = ['program', 'world', 'practice', 'systems'];
const LOG_KINDS = 'gate|ship|decision|drop|defect|migrate|lint|audit';
const STATUS_RE = /\b(NEXT IS|IN PROGRESS|RESUME HERE|OPEN:|BLOCKED|PARKED:|TODO:)/;

// ===== CURRENCY (checks 7-9) =====
// The structural checks above pass on a page that is internally contradictory and four
// buildings out of date -- that is exactly how the 2026-08-16 failures got through, and
// how a backlog entry went on describing a defect two days after it was fixed. See
// practice/wiki-currency.md. These three checks cannot read prose either; what they CAN do
// is notice that the ground under a page moved after the page last claimed to be current,
// and say so. A warning here means RE-READ, not "wrong".
//
// The escape hatch is real and deliberate: bumping `updated:` silences a warning without
// reading anything. That trade is the point -- an invisible rot becomes a visible prompt,
// and the prompt is cheap enough to survive being seen every session.

// Repo paths as the wiki writes them. Extensions run longest-first so .tsx is not clipped
// to .ts. Leading delimiter keeps `docs/foo.md` inside a wikilink or URL from matching.
const CITE_RE =
  /(?:^|[\s`(\[])((?:roblox|server|src|tools|docs|shared-fixtures)\/[A-Za-z0-9._\/-]+\.(?:luau|tsx|ts|mjs|json|md))/g;

// The wiki cites Roblox files both ways -- `roblox/src/shared/X.luau` and, inside world/
// pages that never leave that tree, a bare `src/shared/X.luau`. Both must resolve or the
// check reports phantom dead citations on a third of the world shelf.
const CITE_PREFIXES = ['', 'roblox/'];

const gitDateOf = (absPath) => {
  try {
    return execFileSync('git', ['log', '-1', '--format=%ad', '--date=short', '--', absPath], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
};

export function lint(root, opts = {}) {
  const errors = [];
  const warnings = [];
  // Both injectable so the tests can build a wiki in a tmpdir with no git and no repo.
  const repoRoot = opts.repoRoot ?? resolve(root, '..', '..');
  const gitDate = opts.gitDate ?? gitDateOf;

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

    const updated = (p.text.match(/^updated: (\d{4}-\d{2}-\d{2})$/m) ?? [])[1];
    if (!updated) continue; // check 4 already reported the bad frontmatter

    // 7. the page's own edits outran its `updated:` — schema rule 6, mechanically
    const pageCommitted = gitDate(p.path);
    if (pageCommitted && pageCommitted > updated)
      errors.push(`${p.rel}: committed ${pageCommitted} but frontmatter says updated: ${updated} — bump it`);

    // A page sometimes cites a path in order to say it is GONE -- studio-tooling's Flags
    // section names a Studio mirror that was never committed. That is the note's whole
    // point, so `<!-- lint-ok -->` on the line exempts the citation rather than the page.
    const exempt = new Set(
      p.text
        .split('\n')
        .filter((l) => l.includes('lint-ok'))
        .flatMap((l) => [...l.matchAll(CITE_RE)].map((m) => m[1]))
    );
    const cited = new Set([...p.text.matchAll(CITE_RE)].map((m) => m[1]));
    for (const cite of cited) {
      const abs = CITE_PREFIXES.map((pre) => join(repoRoot, pre + cite)).find(existsSync);
      // 8. dead code citation — the same defect as a dead wikilink, pointed at the repo
      if (!abs) {
        if (!exempt.has(cite)) errors.push(`${p.rel}: dead code citation ${cite}`);
        continue;
      }
      // 9. the ground moved under a page that still claims to be current
      const moved = gitDate(abs);
      if (moved && moved > updated)
        warnings.push(`${p.rel}: re-read — ${cite} changed ${moved}, page updated ${updated}`);
    }
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
